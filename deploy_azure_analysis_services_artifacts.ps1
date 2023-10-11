### Make sure you update below section to suit the respective environment

## This is the secret/string containing user name and password separated by "######"
$AAS_SECRET = "$Env:AAS_SECRET "

## This is the SQL Server login used in data source connection
$SQL_LOGIN_NAME = "$Env:target_sql_login"

## This is the SQL Server login password used in data source connection
$SQL_LOGIN_PASSWORD = "$Env:SQL_LOGIN_PASSWORD"

## This is the URL for Azure Analysis Services endpoint
$SSAS_SERVER_URL = "$Env:ssas_server_url"

## This is the target SQL Server in data source connection
$TARGET_SQL_SERVER = "$Env:target_sql_server"

## This is the target SQL Server database in data source connection
$TARGET_DATABASE = "$Env:target_database"

## This is the tabular model database name
$deployed_db_name = "$Env:deployed_db_name"


echo "DeploySource is: [$Env:DeploySource]"
$DeploySource = "$Env:DeploySource"
dir $DeploySource
dir $DeploySource\Build\Model.bim
[Reflection.Assembly]::LoadWithPartialName("Microsoft.AnalysisServices")
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.AnalysisServices.Tabular.Json");
$json = Get-Content "$DeploySource\Build\Model.bim" -Raw

$interimJsonObj = $json | ConvertFrom-Json
## Remove members property from each role
## Logic for adding role members is moved to separate "Add Role Members" step
ForEach ($role in $interimJsonObj.model.roles) {
    $role.PSObject.Properties.Remove('members')
    $role | add-member -MemberType NoteProperty -Name "members" -Value @()
}
$json = $interimJsonObj | ConvertTo-Json -Depth 100
## write-output $json

#########  Deserialize BIM File JSON into Microsoft.AnalysisServices.Database Object #########
$db = [Microsoft.AnalysisServices.JsonSerializer]::DeserializeDatabase($json)

######### Set Database Name and Data Source, etc #########
$db.Name = "$deployed_db_name"
$db.id = "$deployed_db_name"
$credential = $db.model.datasources[0].Credential
#$db.model.datasources[0].Credential = '{"AuthenticationKind":"UsernamePassword","kind":"SQL","path":"$TARGET_SQL_SERVER;$TARGET_DATABASE","Username":"$SQL_LOGIN_NAME","Password":"xyz","EncryptConnection":false}'
#$db.model.datasources[0].ConnectionDetails = '{"protocol": "tds", "address": {"server": "$TARGET_SQL_SERVER","database": "$TARGET_DATABASE"}, "authentication": null, "query": null}'
$db.model.datasources[0].Credential = "{""AuthenticationKind"":""UsernamePassword"",""kind"":""SQL"",""path"":""$TARGET_SQL_SERVER;$TARGET_DATABASE"",""Username"":""$SQL_LOGIN_NAME"",""Password"":""xyz"",""EncryptConnection"":false}"
$db.model.datasources[0].ConnectionDetails = "{""protocol"": ""tds"", ""address"": {""server"": ""$TARGET_SQL_SERVER"",""database"": ""$TARGET_DATABASE""}, ""authentication"": null, ""query"": null}"

######### Set up SSAS Access Credential  #########
$secret = "$AAS_SECRET"
$tokens = $secret -split "######"
$User = $tokens[0]
$PWord_Plain = $tokens[1]
$PWord = ConvertTo-SecureString -String $PWord_Plain  -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord

######### Set Datasource Password And Create TSML Script From Database Object #########
$script = [Microsoft.AnalysisServices.Tabular.JsonScripter]::ScriptCreateOrReplace($db)
$script
$interimScriptObj = $script | ConvertFrom-Json
$interimScriptObj.createOrReplace.database.model.dataSources[0].credential.Password = "$SQL_LOGIN_PASSWORD"
$script = $interimScriptObj | ConvertTo-Json -Depth 100
$script | Out-File -FilePath .\script.tsml

######### Execute TSML Script #########
$result = Invoke-ASCmd -InputFile ".\script.tsml" -Server "$SSAS_SERVER_URL" -Credential $Credential
if ($result -like "*Exception*") {
    write-host "(ERROR) Deployment Failed!!!! Output: $result"
    Exit 1
}
else {
	write-host "(INFO) Deployment Succeeded! Output: $result"
}