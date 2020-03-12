SET PYTHONVERSION=36
SET pyVirEnvName=venv%PYTHONVERSION%

if  EXIST %~dp0%pyVirEnvName%\ (
    echo "%pyVirEnvName% found"
) ELSE (
    echo "%pyVirEnvName% not found. creating..."
    SET PATH=%LOCALAPPDATA%\Programs\Python\Python%PYTHONVERSION%;%LOCALAPPDATA%\Programs\Python\Python%PYTHONVERSION%\Scripts
    virtualenv %pyVirEnvName%
)

%~dp0%pyVirEnvName%\Scripts\activate.bat
pip install azureml-sdk

