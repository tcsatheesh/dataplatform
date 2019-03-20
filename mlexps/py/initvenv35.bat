SET PYTHONVERSION=35

if  EXIST %~dp0venv35\ (
    echo "venv35 found"
) ELSE (
    echo "venv35 not found. creating..."
    SET PATH=%LOCALAPPDATA%\Programs\Python\Python%PYTHONVERSION%;%LOCALAPPDATA%\Programs\Python\Python%PYTHONVERSION%\Scripts
    virtualenv venv35
)

%~dp0\venv35\Scripts\activate
pip install azureml-sdk

