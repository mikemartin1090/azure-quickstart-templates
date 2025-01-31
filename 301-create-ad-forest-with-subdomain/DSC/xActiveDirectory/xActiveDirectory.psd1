@{
# Version number of this module.
moduleVersion = '2.21.0.0'

# ID used to uniquely identify this module
GUID = '9FECD4F6-8F02-4707-99B3-539E940E9FF5'

# Author of this module
Author = 'Microsoft Corporation'

# Company or vendor of this module
CompanyName = 'Microsoft Corporation'

# Copyright statement for this module
Copyright = '(c) 2014 Microsoft Corporation. All rights reserved.'

# Description of the functionality provided by this module
Description = 'The xActiveDirectory module is originally part of the Windows PowerShell Desired State Configuration (DSC) Resource Kit. This version has been modified for use in Azure. This module contains the xADDomain, xADDomainController, xADUser, and xWaitForDomain resources. These DSC Resources allow you to configure and manage Active Directory.

All of the resources in the DSC Resource Kit are provided AS IS, and are not supported through any Microsoft standard support program or service.'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '4.0'

# Minimum version of the common language runtime (CLR) required by this module
CLRVersion = '4.0'

# Functions to export from this module
FunctionsToExport = '*'

# Cmdlets to export from this module
CmdletsToExport = '*'

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = @('DesiredStateConfiguration', 'DSC', 'DSCResourceKit', 'DSCResource')

        # A URL to the license for this module.
        LicenseUri = 'https://github.com/PowerShell/xActiveDirectory/blob/master/LICENSE'

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/PowerShell/xActiveDirectory'

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
        ReleaseNotes = '* Added xADObjectPermissionEntry
  * New resource added to control the AD object permissions entries [Claudio Spizzi (@claudiospizzi)](https://github.com/claudiospizzi)
* Changes to xADCommon
  * Assert-Module has been extended with a parameter ImportModule to also import the module ([issue 218](https://github.com/PowerShell/xActiveDirectory/issues/218)). [Jan-Hendrik Peters (@nyanhp)](https://github.com/nyanhp)
* Changes to xADDomain
  * xADDomain makes use of new parameter ImportModule of Assert-Module in order to import the ADDSDeployment module ([issue 218](https://github.com/PowerShell/xActiveDirectory/issues/218)). [Jan-Hendrik Peters (@nyanhp)](https://github.com/nyanhp)
* xADComputer, xADGroup, xADOrganizationalUnit and xADUser now support restoring from AD recycle bin ([Issue 221](https://github.com/PowerShell/xActiveDirectory/issues/211)). [Jan-Hendrik Peters (@nyanhp)](https://github.com/nyanhp)

'

    } # End of PSData hashtable

} # End of PrivateData hashtable
}











