# download Python
$url = "https://www.python.org/ftp/python/3.10.11/python-3.10.11-amd64.exe"
$destination = "$env:TEMP\python-3.10.11-amd64.exe"
Invoke-WebRequest -Uri $url -OutFile $destination

# install Python
$installer = "$env:TEMP\python-3.10.11-amd64.exe"
$arguments = "/quiet InstallAllUsers=1 PrependPath=0 Include_test=0 TargetDir=C:\Python310"
Start-Process -FilePath $installer -ArgumentList $arguments -Wait

# pip install azfinsim
$executable = "C:\Python310\python.exe"
$arguments = "-m pip install https://github.com/utkarshayachit/azfinsim/archive/main.zip"
Start-Process -FilePath $executable -ArgumentList $arguments -Wait   
