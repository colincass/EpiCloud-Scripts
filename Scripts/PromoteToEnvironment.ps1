﻿#---------------------------------------------------------------------------
# Name:        PromoteToEnvironment.ps1
#
# Summary:     This script will take the Code, Database, and/or the Blobs 
#              from an environment and promote them to another environment
#
# Version:     1.0
#
# Last Updated: 7/15/2020
#
# Author: Eric Markson - eric.markson@perficient.com | eric@ericmarkson.com | https://www.epivisuals.dev
#
# License: GNU/GPLv3 http://www.gnu.org/licenses/gpl-3.0.html
#---------------------------------------------------------------------------

#Setting up Parameters 
#Setting each Paramater has Mandatory, as they are not optional
#Validating each paramarer for being Null or Empty, using the built in Validator
param
  (
    [Parameter(Position=0, Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ClientKey,
    [Parameter(Position=1, Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ClientSecret,
    [Parameter(Position=2, Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ProjectID,
    [Parameter(Position=3, Mandatory)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet("Integration", "Preproduction", "Production")]
    [string]$SourceEnvironment,
    [Parameter(Position=4, Mandatory)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet("Integration", "Preproduction", "Production")]
    [string]$TargetEnvironment,
    [Parameter(Position=5)]
    [ValidateSet($true, $false, 0, 1)]
    [bool]$UseMaintenancePage = 0,
    [Parameter(Position=6)]
    [ValidateSet($true, $false, 0, 1)]
    [bool]$IncludeCode = 1,
    [Parameter(Position=7)]
    [ValidateSet($true, $false, 0, 1)]
    [bool]$IncludeBlobs = 0,
    [Parameter(Position=8)]
    [ValidateSet($true, $false, 0, 1)]
    [bool]$IncludeDb = 0,
    [Parameter(Position=9)]
    [ValidateSet('cms','commerce')]
    [String] $SourceApp
    
  )

#Checking that the required params exist and are not white space
if([string]::IsNullOrWhiteSpace($ClientKey)){
    throw "A Client Key is needed. Please supply one."
}
if([string]::IsNullOrWhiteSpace($ClientSecret)){
    throw "A Client Secret Key is needed. Please supply one."
}
if([string]::IsNullOrWhiteSpace($ProjectID)){
    throw "A Project ID GUID is needed. Please supply one."
}
if([string]::IsNullOrWhiteSpace($TargetEnvironment)){
    throw "A target deployment environment is needed. Please supply one."
}
if([string]::IsNullOrWhiteSpace($SourceEnvironment)){
    throw "A source deployment environment is needed. Please supply one."
}

if($SourceEnvironment -eq $TargetEnvironment){
    throw "The source environment cannot be the same as the target environment."    
}

Write-Host "Validation passed. Starting Deployment from $SourceEnvironment to $TargetEnvironment"

#If the Module for EpiCloud is not found, install it using the force switch
if (-not (Get-Module -Name EpiCloud -ListAvailable)) {
    Write-Host "Installing EpiServer Cloud Powershell Module"
    Install-Module EpiCloud -Scope CurrentUser -Force
}

Write-Host "Setting up the deployment configuration"

if($IncludeCode -eq $true){
     #Setting up the object for the EpiServer environment deployment
        $startEpiDeploymentSplat = @{
            ProjectId = "$ProjectID"
            Wait = $false
            TargetEnvironment = "$TargetEnvironment"
            SourceEnvironment = "$SourceEnvironment"
            UseMaintenancePage = $UseMaintenancePage
            IncludeBlob = $IncludeBlobs
            IncludeDb = $IncludeDb
            ClientSecret = "$ClientSecret"
            ClientKey = "$ClientKey"
            SourceApp = $SourceApp
        }
    }
    else{
        #Setting up the object for the EpiServer environment deployment
        $startEpiDeploymentSplat = @{
            ProjectId = "$ProjectID"
            Wait = $false
            TargetEnvironment = "$TargetEnvironment"
            SourceEnvironment = "$SourceEnvironment"
            UseMaintenancePage = $UseMaintenancePage
            IncludeBlob = $IncludeBlobs
            IncludeDb = $IncludeDb
            ClientSecret = "$ClientSecret"
            ClientKey = "$ClientKey"
        }
    }




Write-Host "Starting the Deployment to" $TargetEnvironment

#Starting the Deployment
$deploy = Start-EpiDeployment @startEpiDeploymentSplat

$deployId = $deploy | Select -ExpandProperty "id"

#Setting up the object for the EpiServer Deployment Updates
$getEpiDeploymentSplat = @{
    ProjectId = "$ProjectID"
    ClientSecret = "$ClientSecret"
    ClientKey = "$ClientKey"
    Id = "$deployId"
}

#Setting up Variables for progress output
$percentComplete = 0
$currDeploy = Get-EpiDeployment @getEpiDeploymentSplat | Select-Object -First 1
$status = $currDeploy | Select -ExpandProperty "status"
$exit = 0

Write-Host "Percent Complete: $percentComplete%"
Write-Output "##vso[task.setprogress value=$percentComplete]Percent Complete: $percentComplete%"

#While the exit flag is not true
while($exit -ne 1){

#Get the current Deploy
$currDeploy = Get-EpiDeployment @getEpiDeploymentSplat | Select-Object -First 1

#Set the current Percent and Status
$currPercent = $currDeploy | Select -ExpandProperty "percentComplete"
$status = $currDeploy | Select -ExpandProperty "status"

#If the current percent is not equal to what it was before, send an update
#(This is done this way to prevent a bunch of messages to the screen)
if($currPercent -ne $percentComplete){
    Write-Host "Percent Complete: $currPercent%"
    Write-Output "##vso[task.setprogress value=$currPercent]Percent Complete: $currPercent%"
    #Set the overall percent complete variable to the new percent complete
    $percentComplete = $currPercent
}

#If the Percent Complete is equal to 100%, Set the exit flag to true
if($percentComplete -eq 100){
    $exit = 1    
}

#If the status of the deployment is not what it should be for this scipt, Set the exit flad to true
if($status -ne 'InProgress'){
    $exit = 1
}

#Wait 1 second between checks
start-sleep -Milliseconds 1000

}

#If the status is set to Failed, throw an error
if($status -eq "Failed"){
    throw "Deployment Failed. Errors: \n" + $deploy.deploymentErrors
}

Write-Host "Deployment Complete"

#Set the Output variable for the Deployment ID, if needed
Write-Output "##vso[task.setvariable variable=DeploymentId;]'$deployId'"
Write-Verbose "Output Variable Created. Name: DeploymentId | Value: $deployId"
Write-Output "##vso[task.complete result=Succeeded;]"