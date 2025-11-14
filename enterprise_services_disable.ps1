If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit	
}


#https://learn.microsoft.com/en-us/windows/iot/iot-enterprise/optimize/services

# services marked as ok to disable above

$servicesToDisable = @(
    # Per-User Services
    'BluetoothUserService', # Bluetooth User Support Service
    'CaptureService', # Capture Service
    'cbdhsvc', # Clipboard User Service
    'CDPUserSvc', # Connected Devices Platform User Service 
    'ConsentUxUserSvc', # ConsentUX
    'PimIndexMaintenanceSvc', # Contact Data
    'DevicePickerUserSvc', # DevicePicker
    'DevicesFlowUserSvc' , # DevicesFlow
    'BcastDVRUserService' , # GameDVR and Broadcast User Service
    'MessagingService' , # Messaging Service
    'OneSyncSvc' , # Sync Host
    'UdkUserSvc' , # Udk User Service
    'UserDataSvc' , # User Data Access
    'UnistoreSvc' , # User Data Storage

    
    # System Services
    'AxInstSV',           # ActiveX Installer
    'AJRouter',           # AllJoyn Router Service
    'ALG',                # Application Layer Gateway Service
    'AppMgmt',            # Application Management
    'BthAvctpSvc',        # AVCTP Service
    'BITS',               # Background Intelligent Transfer Service
    'BTAGService',        # Bluetooth Audio Gateway Service
    'bthserv',            # Bluetooth Support Service
    'PeerDistSvc',        # BranchCache
    'camsvc',             # Capability Access Manager Service
    'autotimesvc',        # Cellular Time
    'ClipSVC',            # Client License Service
    'CDPSvc',             # Connected Devices Platform Service
    'DiagTrack',          # Connected User Experiences and Telemetry
    'DeviceAssociationService', # Device Association Service
    'DsSvc',              # Data Sharing Service
    'TrkWks',             # Distributed Link Tracking Client
    'MSDTC',              # Distributed Transaction Coordinator
    'MapsBroker',         # Downloaded Maps Manager
    'EntAppSvc',          # Enterprise App Management Service
    'EapHost',            # Extensible Authentication Protocol
    'Fax',                # Fax
    'fdPHost',            # Function Discovery Provider Host
    'FDResPub',           # Function Discovery Resource Publication
    'lfsvc',              # Geolocation Service
    'HvHost',             # HV Host Service
    'vmickvpexchange',    # Hyper-V Data Exchange Service
    'vmicguestinterface', # Hyper-V Guest Service Interface
    'vmicshutdown',       # Hyper-V Guest Shutdown Service
    'vmicheartbeat',      # Hyper-V Heartbeat Service
    'vmicvmsession',      # Hyper-V PowerShell Direct Service
    'vmicrdv',            # Hyper-V Remote Desktop Virtualization Service
    'vmictimesync',       # Hyper-V Time Synchronization Service
    'vmicvss',            # Hyper-V Volume Shadow Copy Requestor
    'SharedAccess',       # Internet Connection Sharing
    'iphlpsvc',           # IP Helper
    'IpxlatCfgSvc',       # IP Translation Configuration Service
    'lltdsvc',            # Link-Layer Topology Discovery Mapper
    'wlpasvc',            # Local Profile Assistance Service
    'wlidsvc',            # Microsoft Account Sign-in Assistant
    'MSiSCSI',            # Microsoft iSCSI Initiator Service
    'NgcSvc',             # Microsoft Passport
    'NgcCtnrSvc',         # Microsoft Passport Container
    'swprv',              # Microsoft Software Shadow Copy Provider
    'smphost',            # Microsoft Storage Spaces SMP
    'InstallService',     # Microsoft Store Install Service
    'SmsRouter',          # Microsoft Windows SMS Router Service
    'NaturalAuthentication', # Natural Authentication
    'Netlogon',           # Netlogon
    'NcdAutoSetup',       # Network Connected Devices Auto-Setup
    'NcbService',         # Network Connection Broker
    'NcaSvc',             # Network Connectivity Assistant
    'NlaSvc',             # Network Location Awareness
    'CscService',         # Offline Files
    'defragsvc',          # Optimize drives
    'WpcMonSvc',          # Parental Controls
    'SEMgrSvc',           # Payments and NFC/SE Manager
    'PNRPsvc',            # Peer Name Resolution Protocol
    'p2psvc',             # Peer Networking Grouping
    'p2pimsvc',           # Peer Networking Identity Manager
    'PhoneSvc',           # Phone Service
    'PNRPAutoReg',        # PNRP Machine Name Publication Service
    'WPDBusEnum',         # Portable Device Enumerator Service
    'Spooler',            # Print Spooler
    'PrintNotify',        # Printer Extensions and Notifications
    'PcaSvc',             # Program Compatibility Assistant Service
    'QWAVE',              # Quality Windows Audio Video Experience
    'RmSvc',              # Radio Management Service
    'RasAuto',            # Remote Access Auto Connection Manager
    'RasMan',             # Remote Access Connection Manager
    'RpcLocator',         # Remote Procedure Call Locator
    'RetailDemo',         # Retail Demo Service
    'SstpSvc',            # Secure Socket Tunneling Protocol Service
    'SensorDataService',  # Sensor Data Service
    'SensrSvc',           # Sensor Monitoring Service
    'SensorService',      # Sensor Service
    'LanmanServer',       # Server
    'shpamsvc',           # Shared PC Account Manager
    'ShellHWDetection',   # Shell Hardware Detection
    'SCardSvr',           # Smart Card
    'ScDeviceEnum',       # Smart Card Device Enumeration Service
    'SCPolicySvc',        # Smart Card Removal Policy
    'SNMPTRAP',           # SNMP Trap
    'SSDPSRV',            # SSDP Discovery
    'WiaRpc',             # Still Image Acquisition Events
    'lmhosts',            # TCP/IP NetBIOS Helper
    'TapiSrv',            # Telephony
    'Themes',             # Themes
    'TabletInputService', # Touch Keyboard and Handwriting Panel Service
    'upnphost',           # UPnP Device Host
    'VSS',                # Volume Shadow Copy
    'VacSvc',             # Volumetric Audio Compositor Service
    'WalletService',      # WalletService
    'WarpJITSvc',         # WarpJITSvc
    'TokenBroker',        # Web Account Manager
    'WebClient',          # Web Client
    'WFDSConMgrSvc',      # Wi-Fi Direct Services Connection Manager
    'Audiosrv',           # Windows Audio
    'AudioEndpointBuilder', # Windows Audio Endpoint Builder
    'SDRSVC',             # Windows Backup
    'WbioSrvc',           # Windows Biometric Service
    'FrameServer',        # Windows Camera Frame Server
    'Wcncsvc',            # Windows Connect Now - Config Registrar
    'Wcmsvc',             # Windows Connection Manager
    'WEPHOSTSVC',         # Windows Encryption Provider Host Service
    'stisvc',             # Windows Image Acquisition
    'wisvc',              # Windows Insider Service
    'LicenseManager',     # Windows License Manager Service
    'WMPNetworkSvc',      # Windows Media Player Network Sharing Service
    'icssvc',             # Windows Mobile Hotspot Service
    'spectrum',           # Windows Perception Service
    'perceptionsimulation', # Windows Perception Simulation Service
    'PushToInstall',      # Windows PushToInstall Service
    'WSearch',            # Windows Search
    'wuauserv',           # Windows Update
    'dot3svc',            # Wired AutoConfig
    'WLANSVC',            # WLAN Autoconfig
    'workfolderssvc',     # Work Folders
    'WwanSvc',            # WWAN AutoConfig
    'XboxGipSvc',         # Xbox Accessory Management Service
    'XblAuthManager',     # Xbox Live Auth Manager
    'XblGameSave',        # Xbox Live Game Save
    'XboxNetApiSvc'       # Xbox Live Networking Service
)


foreach ($service in $servicesToDisable) { 
    try {
        Set-Service -Name $service -StartupType Disabled -ErrorAction Stop
    }
    catch {
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$service"
        Set-ItemProperty -Path $regPath -Name 'Start' -Value 4 -ErrorAction SilentlyContinue
    }
}