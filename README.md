# QuickPinger

Quick and Dirty Script to check is CIDR has pingable objects

## Getting Started

[Simple steps to get this program running]

## Maintaining Project

This project uses the ManagePSProject module which is used to maintain this project during it's lifecycle. See the below commands:

```powershell
# Possible Commands
ManagePSProject [-Build] [-Reset] [-Publish] [-Flush] 
                [-Init] [-GetInfo] [-SetInfo] [-SemVer] 
                [-Develop] [-GenUTIL] [-AddDeps] [-ListDeps]

ManagePSProject -Build # Packages project and increments version number
ManagePSProject -Reset # Resets project's info
ManagePSProject -Publish "Sample Commit Message" # Pushes this repository to remote git repo
ManagePSProject -Flush # Clears 'releases' folder
ManagePSProject -Init # Initializes projectinfo config file for the project and builds project environment
ManagePSProject -GetInfo # Returns the current information of project
ManagePSProject -SetInfo # Sets information of project
ManagePSProject -SemVer # Returns the current Semantic Version
ManagePSProject -Develop "Arguments for main script" # Runs application in development mode
ManagePSProject -GenUTIL # Generates Utility for Project saved to utils folder
ManagePSProject -AddDeps "https://github.com/random/repo" # Adds a powershell github repo to script session, can add several by using space delimiter
ManagePSProject -ListDeps # Displays the dependencies of this project
```

### Main Script

The main script, titled '[QuickPinger.ps1](QuickPinger.ps1)' example is where the project will be launched from.

### Sub Folders

The template contains included folders which each serve a purpose as defined below.

#### 'config' Folder

The 'config' folder should contain configuration files. For example a sample 'config' folder might contain config.cfg

#### 'installers' Folder

The 'installers' folder should contain installers and other executables. For example a sample 'installers' folder might contain Chrome.exe and Dropbox.exe

#### 'utils' Folder

The 'utils' folder should only contain scripts which can then be dot-sourced into the main powershell script.

#### 'releases' Folder

The 'releases' folder will contain the most recent build of the powershell deployment package. When changes are made to this repository, you can run the packaging utility to create a zip of the entire project.
