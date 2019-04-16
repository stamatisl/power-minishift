function CheckDockerForWindows() {

    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    
    $docker = Get-Process -name 'Docker for Windows' -ErrorAction SilentlyContinue

    if (!$docker) {
        [System.Windows.Forms.MessageBox]::Show("Docker for windows isn't running!","Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Hand)
        exit 
    }

    $docker = Get-Process -Name 'com.docker.proxy' -ErrorAction SilentlyContinue

    if (!$docker) {
        [System.Windows.Forms.MessageBox]::Show("com.docker.proxy isn't running!","Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Hand)
        exit
    }

    $VMName = Get-VM -name 'MobyLinuxVM'
    
    if (!$VMname) { 
        [System.Windows.Forms.MessageBox]::Show("MobyLinuxVM not found!","Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Hand)
        exit
    }
    elseif ($VMName.State -ne "Running")  { 
        [System.Windows.Forms.MessageBox]::Show("MobyLinuxVM isn't running!","Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Hand)
        exit
    }

    $VMSwitch = Get-VMSwitch -name 'DockerNAT'
    
    if (!$VMSwitch) { 
        [System.Windows.Forms.MessageBox]::Show("DockerNAT vSwitch not found!","Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Hand)
        exit
    }

    $VMSwitch = Get-VMSwitch -name 'Default Switch'

    if (!$VMSwitch) { 
        [System.Windows.Forms.MessageBox]::Show("Default Switch vSwitch not found!","Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Hand)
        exit
    }
}

function StartMinishift($filenamepath) {

    # & $filenamepath start --show-libmachine-logs -v 5 | Out-Host
    $process = Get-Process -Name minishift -ErrorAction SilentlyContinue
    while ($process) {
        $process = Get-Process -Name minishift -ErrorAction SilentlyContinue
        Stop-Process -Name minishift -Force
        Write-Output "Please wait ..."
        Start-Sleep -Seconds 5
    }
    & $filenamepath start --show-libmachine-logs | Out-Host
    Write-Output "Minishift installation completed succesfully"

}

function SetupDriver($driver,$installationpath) {

    # C:\Users\user\.minishift\config\config.json
    & $installationpath'\minishift.exe' stop
    & $installationpath'\minishift.exe' delete --force --clear-cache -v 5 | Out-Host
    Remove-Item -Force $env:UserProfile\.minishift\ -Recurse

    if ($driver -eq "virtualbox") { 
        & $installationpath'\minishift.exe' config set vm-driver virtualbox
    }

    if ($driver -eq "hyperv") { 
        Import-Module –Name Hyper-V
        Write-Host $driver
        $Hyperv_VM = Get-VM -Name minishift -ErrorAction SilentlyContinue
        if ($Hyperv_VM) { 
            if($Hyperv_VM.PowerState -eq "PoweredOn"){ Stop-VM -VM "minishift" -Confirm:false }
        Get-VM -Name minishift | Remove-VM -Confirm:false
        }
        & $installationpath'\minishift.exe' config set vm-driver hyperv
        & $installationpath'\minishift.exe' config set hyperv-virtual-switch "Default Switch"
    }

}

function InstallDockerDesktop($filenamepath) {

    $ps = new-object System.Diagnostics.Process
    $ps.StartInfo.Filename = $filenamepath
    $ps.StartInfo.RedirectStandardOutput = $True
    $ps.StartInfo.UseShellExecute = $false
    $ps.Start()
    $ps.WaitForExit()
    Write-Output "Docker Desktop installation completed succesfully"
    
    $process = Get-Process -Name com.docker.proxy -ErrorAction SilentlyContinue
    
    while (!$process) {
        $process = Get-Process -Name com.docker.proxy -ErrorAction SilentlyContinue
        Write-Output "Please start Docker Desktop appication ..."
        Start-Sleep -Seconds 5
    }

}


function InstallSoftware($filenamepath) {

    $ps = new-object System.Diagnostics.Process
    $ps.StartInfo.Filename = $filenamepath
    $ps.StartInfo.Arguments = " --silent"
    $ps.StartInfo.RedirectStandardOutput = $True
    $ps.StartInfo.UseShellExecute = $false
    $ps.Start()
    $ps.WaitForExit()
    Write-Output "VirtualBox installation completed succesfully"

}

function DownloadFile($url,$filenamepath) {
    
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $start_time = Get-Date
    Invoke-WebRequest -Uri $url -OutFile $filenamepath
    Write-Output "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    CheckIfDownloaded $url $filenamepath

}

function CheckIfDownloaded($url,$filenamepath) {

    #Write-Host $filenamepath

    If (Test-Path $filenamepath) { 
        Write-Output "$filenamepath already in the folder"

    } 
    
    else { 
        Write-Host $url
        DownloadFile $url $filenamepath
    }

}

function CheckIfInstalled($software) {
    
    $installed = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where { $_.DisplayName -like $software }) -ne $null
    return $installed
    
}

function CheckHyperV() {

    $hyperv = Get-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V-All -Online

    if($hyperv.State -eq "Enabled") {

        Import-Module –Name Hyper-V 
        Write-Host "Hyper-V is enabled."
        Add-Type -AssemblyName system.Windows.Forms
        $SetBackupLocation = New-Object System.Windows.Forms.FolderBrowserDialog
        $SetBackupLocation.Description = "Please select Minishift installation folder"
        $rc = $SetBackupLocation.ShowDialog()
	
        if ($rc -eq [System.Windows.Forms.DialogResult]::OK) {

            $installationpath = $SetBackupLocation.SelectedPath
            Write-Host $installationpath

            $url = "https://github.com/minishift/minishift/releases/download/v1.33.0/minishift-systemtray-1.33.0-windows-amd64.zip"
            $filenamepath = "$installationpath\minishift-systemtray-1.33.0-windows-amd64.zip"
            
            CheckIfDownloaded $url $filenamepath
            Expand-Archive $filenamepath -DestinationPath $installationpath -Force
            
            Copy-Item -Path "$installationpath\minishift-systemtray-1.33.0-windows-amd64\minishift.exe" "$installationpath\minishift.exe" -Force
            
            $groupObj =[ADSI]"WinNT://./Hyper-V Administrators,group" 
            $membersObj = @($groupObj.psbase.Invoke("Members")) 
            $members = ($membersObj | foreach {$_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null)})
            If ($members -contains $env:Username) {
                 Write-Host "$env:Username exists in the group Hyper-V Administrators"
            } 
            else {
                ([adsi]"WinNT://./Hyper-V Administrators,group").Add("WinNT://$env:UserDomain/$env:Username,user")
            }

            $software = "*Docker Desktop*"
            $installed = CheckIfInstalled $software

            if(-Not $installed) {
                Write-Host "Docker Desktop is NOT installed."
                $url = "https://download.docker.com/win/stable/Docker%20for%20Windows%20Installer.exe"
                $filenamepath = "$installationpath\Docker for Windows Installer.exe"
                Write-Host $filenamepath
    	        CheckIfDownloaded $url $filenamepath
                InstallDockerDesktop $filenamepath
            } 
    
            else {
                Write-Host "Docker Desktop is installed."
            }

            $filenamepath = "$installationpath\minishift"
            CheckDockerForWindows 
            SetupDriver "hyperv" $installationpath
            StartMinishift $filenamepath
            Write-Host "Hyper-V is enabled."
        }

        else {
            exit
        }
    }

    else {

        Write-Host "Hyper-V is disabled."
        Add-Type -AssemblyName system.Windows.Forms
        $SetBackupLocation = New-Object System.Windows.Forms.FolderBrowserDialog
        $SetBackupLocation.Description = "Please select Minishift installation folder"
        $rc = $SetBackupLocation.ShowDialog()
	
        if ($rc -eq [System.Windows.Forms.DialogResult]::OK) {

            $installationpath = $SetBackupLocation.SelectedPath
            Write-Host $installationpath
        
            $software = "*Oracle VM VirtualBox*"
            $installed = CheckIfInstalled $software

            if(-Not $installed) {
                Write-Host "Oracle VM VirtualBox is NOT installed."
                $url = "https://download.virtualbox.org/virtualbox/6.0.4/VirtualBox-6.0.4-128413-Win.exe"
                $filenamepath = "$installationpath\VirtualBox-6.0.4-128413-Win.exe"
                Write-Host $filenamepath
    	        CheckIfDownloaded $url $filenamepath
                InstallSoftware $filenamepath
            } 
    
            else {
                Write-Host "Oracle VM VirtualBox is installed."
            }

        $url = "https://github.com/minishift/minishift/releases/download/v1.33.0/minishift-systemtray-1.33.0-windows-amd64.zip"
        $filenamepath = "$installationpath\minishift-systemtray-1.33.0-windows-amd64.zip"
        CheckIfDownloaded $url $filenamepath
        Expand-Archive $filenamepath -DestinationPath $installationpath -Force
        Copy-Item -Path "$installationpath\minishift-systemtray-1.33.0-windows-amd64\minishift.exe" "$installationpath\minishift.exe" -Force
        
        $url = "https://github.com/minishift/minishift/files/3068111/ssh.zip"
        $filenamepath = "$installationpath\ssh.zip"
        CheckIfDownloaded $url $filenamepath
        Expand-Archive $filenamepath -DestinationPath $installationpath -Force
        Copy-Item -Path "$installationpath\ssh.exe" "$env:SystemRoot\System32\ssh.exe" -Force

        $url = "https://github.com/openshift/origin/releases/download/v3.11.0/openshift-origin-client-tools-v3.11.0-0cbc58b-windows.zip"
        $filenamepath = "$installationpath\openshift-origin-client-tools-v3.11.0-0cbc58b-windows.zip"
        CheckIfDownloaded $url $filenamepath
        Expand-Archive $filenamepath -DestinationPath $installationpath -Force

        $filenamepath = "$installationpath\minishift"
        SetupDriver "virtualbox" $installationpath
        StartMinishift $filenamepath

        }
        
    }

}

CheckHyperV
[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[System.Windows.Forms.MessageBox]::Show("Done!","Information",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information)



### COMMENTS ###
#Write-Host "Press any key to continue ....."
#$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V –All
# Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V
# dism /Online /Disable-Feature:Microsoft-Hyper-V 
# bcdedit /set hypervisorlaunchtype off

# $net = Get-NetIPConfiguration | where {$_.IPv4DefaultGateway -ne $null } | select -ExpandProperty InterfaceAlias
# New-VMSwitch -Name "External VM Switch" -AllowManagementOS $True -NetAdapterName $net
# New-VMSwitch -Name "minishift0" -SwitchType "Internal" -NATSubnetAddress "10.11.22.0/24"
# New-NetNat -Name "minishift0nat" -InternalIPInterfaceAddressPrefix "10.11.22.0/24"

            
# {
# "hyperv-virtual-switch": "minishift0",
# "vm-driver": "hyperv"
# }
# "vm-driver": "virtualbox"
             
# reg ADD "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Virtualization\Containers" /v TemplateVmCount /t REG_DWORD /d 0
# reg ADD "HKLM\System\CurrentControlSet\Services\LanmanServer\Parameters" /v DisableStrictNameChecking /t REG_DWORD /d 1
# Get-NetAdapter  get ifIndex
# New-NetIPAddress -IPAddress 10.11.22.1 -PrefixLength 24 -InterfaceIndex 41
# New-NetNat -Name "minishift0nat" -InternalIPInterfaceAddressPrefix 10.11.22.0/24
# Get-VM -Name "minishift" | Get-VMNetworkAdapter | Connect-VMNetworkAdapter -SwitchName "minishift0"

#$ps = new-object System.Diagnostics.Process
#$ps.StartInfo.Filename = $filenamepath
#$ps.StartInfo.Arguments = " start"
#$ps.StartInfo.RedirectStandardOutput = $True
#$ps.StartInfo.UseShellExecute = $false
#$ps.Start() | Out-Host
#$ps.WaitForExit()