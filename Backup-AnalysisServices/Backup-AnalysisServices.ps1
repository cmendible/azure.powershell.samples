<# 
    .SYNOPSIS 
        Backup-AnalysisServices is a simple PowerShell workflow runbook that will help you automate the process of backing up an Azure Analysis Service Database. 
     
    .DESCRIPTION 
        Backup-AnalysisServices is a simple PowerShell workflow runbook that will help you automate the process of backing up an Azure Analysis Service Database. 
 
    .PARAMETER ResourceGroupName 
        The name of the resource group where the cluster resides 
     
    .PARAMETER AutomationCredentialName 
        The Automation credential holdind username and password for Analysis Services 
     
    .PARAMETER AnalysisServiceDatabase 
        The Analysis Service Database 
 
    .PARAMETER AnalysisServiceServer 
        The Analysis Service Server

    .PARAMETER ConnectionName 
        The name of your automation connection account. Defaults to  'AzureRunAsConnection'
    
    .NOTES  
        AUTHOR: Carlos Mendible  
        LASTEDIT: October 17, 2017  
#> 
workflow Backup-AnalysisServices { 
    Param 
    (    
        [Parameter(Mandatory = $true)] 
        [String]$ResourceGroupName, 
 
        [Parameter(Mandatory = $true)] 
        [String]$AutomationCredentialName, 
 
        [Parameter(Mandatory = $true)] 
        [String]$AnalysisServiceDatabase, 

        [Parameter(Mandatory = $true)] 
        [String]$AnalysisServiceServer,
 
        [Parameter(Mandatory = $false)] 
        [String]$ConnectionName 
    ) 

    # Requires the AzureRM.Profile and SqlServer PowerShell Modules

    $automationConnectionName = $ConnectionName 
    if (!$ConnectionName) { 
        $automationConnectionName = "AzureRunAsConnection" 
    } 
     
    # Get the connection by name (i.e. AzureRunAsConnection) 
    $servicePrincipalConnection = Get-AutomationConnection -Name $automationConnectionName          
 
    Write-Output "Logging in to Azure..." 
     
    Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint

    # Get PSCredential 
    $cred = Get-AutomationPSCredential -Name $AutomationCredentialName
  
    Write-Output "Starting Backup..." 
    
    Backup-ASDatabase `
        –backupfile ("backup." + (Get-Date).ToString("yyMMdd") + ".abf") `
        –name $AnalysisServiceDatabase `
        -server $AnalysisServiceServer `
        -Credential $cred
}