@echo off
set "PATH=C:\Program Files\nodejs;C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin;%PATH%"
"C:\Program Files\nodejs\npx.cmd" -y @azure-devops/mcp mariner-org --authentication azcli -d all
