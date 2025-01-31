$Global:DSCModuleName      = 'xActiveDirectory'
$Global:DSCResourceName    = 'MSFT_xADUser'

#region HEADER
[String] $moduleRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $Script:MyInvocation.MyCommand.Path))
if ( (-not (Test-Path -Path (Join-Path -Path $moduleRoot -ChildPath 'DSCResource.Tests'))) -or `
     (-not (Test-Path -Path (Join-Path -Path $moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1'))) )
{
    & git @('clone','https://github.com/PowerShell/DscResource.Tests.git',(Join-Path -Path $moduleRoot -ChildPath '\DSCResource.Tests\'))
}

Import-Module (Join-Path -Path $moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1') -Force
$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $Global:DSCModuleName `
    -DSCResourceName $Global:DSCResourceName `
    -TestType Unit
#endregion HEADER


# Begin Testing
try
{

    #region Pester Tests

    InModuleScope $Global:DSCResourceName {

        $testPresentParams = @{
            DomainName = 'contoso.com';
            UserName = 'TestUser';
            Ensure = 'Present';
        }

        $testAbsentParams = $testPresentParams.Clone();
        $testAbsentParams['Ensure'] = 'Absent';

        $fakeADUser = @{
            DistinguishedName = "CN=$($testPresentParams.UserName),CN=Users,DC=contoso,DC=com";
            Enabled = $true;
            GivenName = '';
            Name = $testPresentParams.UserName;
            SamAccountName = $testPresentParams.UserName;
            Surname = '';
            UserPrincipalName = '';
        }

        $testDomainController = 'TESTDC';
        $testCredential = [System.Management.Automation.PSCredential]::Empty;

        $testStringProperties = @(
            'UserPrincipalName', 'DisplayName', 'Path',  'GivenName', 'Initials', 'Surname', 'Description', 'StreetAddress',
            'POBox', 'City', 'State', 'PostalCode', 'Country', 'Department', 'Division', 'Company', 'Office', 'JobTitle',
            'EmailAddress', 'EmployeeID', 'EmployeeNumber', 'HomeDirectory', 'HomeDrive', 'HomePage', 'ProfilePath',
            'LogonScript', 'Notes', 'OfficePhone', 'MobilePhone', 'Fax', 'Pager', 'IPPhone', 'HomePhone','CommonName'
        );
        $testBooleanProperties = @('PasswordNeverExpires', 'CannotChangePassword','Enabled');

        #region Function Get-TargetResource
        Describe "$($Global:DSCResourceName)\Get-TargetResource" {

            It "Returns a 'System.Collections.Hashtable' object type" {
                Mock -CommandName Get-ADUser -MockWith { return [PSCustomObject] $fakeADUser; }

                $adUser = Get-TargetResource @testPresentParams;

                $adUser -is [System.Collections.Hashtable] | Should Be $true;
            }

            It "Returns 'Ensure' is 'Present' when user account exists" {
                Mock -CommandName Get-ADUser -MockWith { return [PSCustomObject] $fakeADUser; }

                $adUser = Get-TargetResource @testPresentParams;

                $adUser.Ensure | Should Be 'Present';
            }

            It "Returns 'Ensure' is 'Absent' when user account does not exist" {
                Mock -CommandName Get-ADUser -MockWith { throw New-Object Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException }

                $adUser = Get-TargetResource @testPresentParams;

                $adUser.Ensure | Should Be 'Absent';
            }

            It "Calls 'Get-ADUser' with 'Server' parameter when 'DomainController' specified" {
                Mock -CommandName Get-ADUser -ParameterFilter { $Server -eq $testDomainController } -MockWith { return [PSCustomObject] $fakeADUser; }

                Get-TargetResource @testPresentParams -DomainController $testDomainController;

                Assert-MockCalled -CommandName Get-ADUser -ParameterFilter { $Server -eq $testDomainController } -Scope It
            }

            It "Calls 'Get-ADUser' with 'Credential' parameter when 'DomainAdministratorCredential' specified" {
                Mock -CommandName Get-ADUser -ParameterFilter { $Credential -eq $testCredential } -MockWith { return [PSCustomObject] $fakeADUser; }

                Get-TargetResource @testPresentParams -DomainAdministratorCredential $testCredential;

                Assert-MockCalled -CommandName Get-ADUser -ParameterFilter { $Credential -eq $testCredential } -Scope It
            }

        }
        #endregion

        #region Function Test-TargetResource
        Describe "$($Global:DSCResourceName)\Test-TargetResource" {

            It "Passes when user account does not exist and 'Ensure' is 'Absent'" {
                Mock -CommandName Get-TargetResource -MockWith { return $testAbsentParams }

                Test-TargetResource @testAbsentParams | Should Be $true;
            }

            It "Passes when user account exists and 'Ensure' is 'Present'" {
                Mock -CommandName Get-TargetResource -MockWith { return $testPresentParams }

                Test-TargetResource @testPresentParams | Should Be $true;
            }

            It "Passes when user account password matches and 'Password' is specified" {
                Mock -CommandName Get-TargetResource -MockWith { return $testPresentParams }
                Mock -CommandName Test-Password { return $true; }

                Test-TargetResource @testPresentParams -Password $testCredential | Should Be $true;
            }

            It "Fails when user account does not exist and 'Ensure' is 'Present'" {
                Mock -CommandName Get-TargetResource -MockWith { return $testAbsentParams }

                Test-TargetResource @testPresentParams | Should Be $false;
            }

            It "Fails when user account exists, and 'Ensure' is 'Absent'" {
                Mock -CommandName Get-TargetResource -MockWith { return $testPresentParams }

                Test-TargetResource @testAbsentParams | Should Be $false;
            }

            It "Fails when user account password is incorrect and 'Password' is specified" {
                Mock -CommandName Get-TargetResource -MockWith { return $testPresentParams }
                Mock -CommandName Test-Password { return $false; }

                Test-TargetResource @testPresentParams -Password $testCredential | Should Be $false;
            }

            It "Calls 'Test-Password' with 'Default' PasswordAuthentication by default" {
                Mock -CommandName Get-TargetResource -MockWith { return $testPresentParams }
                Mock -CommandName Test-Password -ParameterFilter { $PasswordAuthentication -eq 'Default' } { return $true; }

                Test-TargetResource @testPresentParams -Password $testCredential;

                Assert-MockCalled -CommandName Test-Password -ParameterFilter { $PasswordAuthentication -eq 'Default' } -Scope It
            }

            It "Calls 'Test-Password' with 'Negotiate' PasswordAuthentication when specified" {
                Mock -CommandName Get-TargetResource -MockWith { return $testPresentParams }
                Mock -CommandName Test-Password -ParameterFilter { $PasswordAuthentication -eq 'Negotiate' } { return $false; }

                Test-TargetResource @testPresentParams -Password $testCredential -PasswordAuthentication 'Negotiate';

                Assert-MockCalled -CommandName Test-Password -ParameterFilter { $PasswordAuthentication -eq 'Negotiate' } -Scope It
            }

            foreach ($testParameter in $testStringProperties) {

                It "Passes when user account '$testParameter' matches AD account property" {
                    $testParameterValue = 'Test Parameter String Value';
                    $testValidPresentParams = $testPresentParams.Clone();
                    $testValidPresentParams[$testParameter] = $testParameterValue;
                    $validADUser = $testPresentParams.Clone();
                    $invalidADUser = $testPresentParams.Clone();
                    Mock -CommandName Get-TargetResource -MockWith {
                        $validADUser[$testParameter] = $testParameterValue;
                        return $validADUser;
                    }

                    Test-TargetResource @testValidPresentParams | Should Be $true;
                }

                It "Fails when user account '$testParameter' does not match incorrect AD account property value" {
                    $testParameterValue = 'Test Parameter String Value';
                    $testValidPresentParams = $testPresentParams.Clone();
                    $testValidPresentParams[$testParameter] = $testParameterValue;
                    $validADUser = $testPresentParams.Clone();
                    $invalidADUser = $testPresentParams.Clone();
                    Mock -CommandName Get-TargetResource -MockWith {
                        $invalidADUser[$testParameter] = $testParameterValue.Substring(0, ([System.Int32] $testParameterValue.Length/2));
                        return $invalidADUser;
                    }

                    Test-TargetResource @testValidPresentParams | Should Be $false;
                }

                It "Fails when user account '$testParameter' does not match empty AD account property value" {
                    $testParameterValue = 'Test Parameter String Value';
                    $testValidPresentParams = $testPresentParams.Clone();
                    $testValidPresentParams[$testParameter] = $testParameterValue;
                    $validADUser = $testPresentParams.Clone();
                    $invalidADUser = $testPresentParams.Clone();
                    Mock -CommandName Get-TargetResource -MockWith {
                        $invalidADUser[$testParameter] = '';
                        return $invalidADUser;
                    }

                    Test-TargetResource @testValidPresentParams | Should Be $false;
                }

                It "Fails when user account '$testParameter' does not match null AD account property value" {
                    $testParameterValue = 'Test Parameter String Value';
                    $testValidPresentParams = $testPresentParams.Clone();
                    $testValidPresentParams[$testParameter] = $testParameterValue;
                    $validADUser = $testPresentParams.Clone();
                    $invalidADUser = $testPresentParams.Clone();
                    Mock -CommandName Get-TargetResource -MockWith {
                        $invalidADUser[$testParameter] = $null;
                        return $invalidADUser;
                    }

                    Test-TargetResource @testValidPresentParams | Should Be $false;
                }

                It "Passes when empty user account '$testParameter' matches empty AD account property" {
                    $testValidPresentParams = $testPresentParams.Clone();
                    $testValidPresentParams[$testParameter] = $testParameterValue;
                    $validADUser = $testPresentParams.Clone();
                    Mock -CommandName Get-TargetResource -MockWith {
                        $validADUser[$testParameter] = '';
                        return $validADUser;
                    }

                    Test-TargetResource @testValidPresentParams | Should Be $true;
                }

                It "Passes when empty user account '$testParameter' matches null AD account property" {
                    $testValidPresentParams = $testPresentParams.Clone();
                    $testValidPresentParams[$testParameter] = $testParameterValue;
                    $validADUser = $testPresentParams.Clone();
                    Mock -CommandName Get-TargetResource -MockWith {
                        $validADUser[$testParameter] = $null;
                        return $validADUser;
                    }

                    Test-TargetResource @testValidPresentParams | Should Be $true;
                }

            } #end foreach test string property

            foreach ($testParameter in $testBooleanProperties) {

                It "Passes when user account '$testParameter' matches AD account property" {
                    $testParameterValue = $true;
                    $testValidPresentParams = $testPresentParams.Clone();
                    $testValidPresentParams[$testParameter] = $testParameterValue;
                    $validADUser = $testPresentParams.Clone();
                    $invalidADUser = $testPresentParams.Clone();
                    Mock -CommandName Get-TargetResource -MockWith {
                        $validADUser[$testParameter] = $testParameterValue;
                        return $validADUser;
                    }

                    Test-TargetResource @testValidPresentParams | Should Be $true;
                }

                It "Fails when user account '$testParameter' does not match AD account property value" {
                    $testParameterValue = $true;
                    $testValidPresentParams = $testPresentParams.Clone();
                    $testValidPresentParams[$testParameter] = $testParameterValue;
                    $validADUser = $testPresentParams.Clone();
                    $invalidADUser = $testPresentParams.Clone();
                    Mock -CommandName Get-TargetResource -MockWith {
                        $invalidADUser[$testParameter] = -not $testParameterValue;
                        return $invalidADUser;
                    }

                    Test-TargetResource @testValidPresentParams | Should Be $false;
                }

            } #end foreach test boolean property

        }
        #endregion

        #region Function Set-TargetResource
        Describe "$($Global:DSCResourceName)\Set-TargetResource" {

            It "Calls 'New-ADUser' when 'Ensure' is 'Present' and the account does not exist" {
                $newUserName = 'NewUser'
                $newAbsentParams = $testAbsentParams.Clone();
                $newAbsentParams['UserName'] = $newUserName;
                $newPresentParams = $testPresentParams.Clone();
                $newPresentParams['UserName'] = $newUserName;
                Mock -CommandName New-ADUser -ParameterFilter { $Name -eq $newUserName }
                Mock -CommandName Set-ADUser
                Mock -CommandName Get-TargetResource -ParameterFilter { $Username -eq $newUserName } { return $newAbsentParams; }

                Set-TargetResource @newPresentParams;

                Assert-MockCalled -CommandName New-ADUser -ParameterFilter { $Name -eq $newUserName } -Scope It
            }

            It "Calls 'Move-ADObject' when 'Ensure' is 'Present', the account exists but Path is incorrect" {
                $testTargetPath = 'CN=Users,DC=contoso,DC=com';
                Mock -CommandName Set-ADUser
                Mock -CommandName Get-ADUser -MockWith {
                    $duffADUser = $fakeADUser.Clone();
                    $duffADUser['DistinguishedName'] = "CN=$($testPresentParams.UserName),OU=WrongPath,DC=contoso,DC=com";
                    return $duffADUser;
                }
                Mock -CommandName Move-ADObject -ParameterFilter { $TargetPath -eq $testTargetPath }

                Set-TargetResource @testPresentParams -Path $testTargetPath -Enabled $true;

                Assert-MockCalled -CommandName Move-ADObject -ParameterFilter { $TargetPath -eq $testTargetPath } -Scope It
            }

            It "Calls 'Rename-ADObject' when 'Ensure' is 'Present', the account exists but 'CommonName' is incorrect" {
                $testCommonName = 'Test Common Name';
                Mock -CommandName Set-ADUser
                Mock -CommandName Get-ADUser -MockWith { return $fakeADUser; }
                Mock -CommandName Rename-ADObject -ParameterFilter { $NewName -eq $testCommonName }

                Set-TargetResource @testPresentParams -CommonName $testCommonName -Enabled $true;

                Assert-MockCalled -CommandName Rename-ADObject -ParameterFilter { $NewName -eq $testCommonName } -Scope It
            }

            It "Calls 'Set-ADAccountPassword' when 'Password' parameter is specified" {
                Mock -CommandName Get-ADUser -MockWith { return $fakeADUser; }
                Mock -CommandName Set-ADUser
                Mock -CommandName Set-ADAccountPassword -ParameterFilter { $NewPassword -eq $testCredential.Password }

                Set-TargetResource @testPresentParams -Password $testCredential;

                Assert-MockCalled -CommandName Set-ADAccountPassword -ParameterFilter { $NewPassword -eq $testCredential.Password } -Scope It
            }

            It "Calls 'Set-ADUser' with 'Replace' when existing matching AD property is null" {
                $testADPropertyName = 'Description';
                Mock -CommandName Get-ADUser -MockWith {
                    $duffADUser = $fakeADUser.Clone();
                    $duffADUser[$testADPropertyName] = $null;
                    return $duffADUser;
                }
                Mock -CommandName Set-ADUser -ParameterFilter { $Replace.ContainsKey($testADPropertyName) }

                Set-TargetResource @testPresentParams -Description 'My custom description';

                Assert-MockCalled -CommandName Set-ADUser -ParameterFilter { $Replace.ContainsKey($testADPropertyName) } -Scope It -Exactly 1;
            }

            It "Calls 'Set-ADUser' with 'Replace' when existing matching AD property is empty" {
                $testADPropertyName = 'Description';
                Mock -CommandName Get-ADUser -MockWith {
                    $duffADUser = $fakeADUser.Clone();
                    $duffADUser[$testADPropertyName] = '';
                    return $duffADUser;
                }
                Mock -CommandName Set-ADUser -ParameterFilter { $Replace.ContainsKey($testADPropertyName) }

                Set-TargetResource @testPresentParams -Description 'My custom description';

                Assert-MockCalled -CommandName Set-ADUser -ParameterFilter { $Replace.ContainsKey($testADPropertyName) } -Scope It -Exactly 1;
            }

            It "Calls 'Set-ADUser' with 'Remove' when new matching AD property is empty" {
                $testADPropertyName = 'Description';
                Mock -CommandName Get-ADUser -MockWith {
                    $duffADUser = $fakeADUser.Clone();
                    $duffADUser[$testADPropertyName] = 'Incorrect parameter value';
                    return $duffADUser;
                }
                Mock -CommandName Set-ADUser -ParameterFilter { $Remove.ContainsKey($testADPropertyName) }

                Set-TargetResource @testPresentParams -Description '';

                Assert-MockCalled -CommandName Set-ADUser -ParameterFilter { $Remove.ContainsKey($testADPropertyName) } -Scope It -Exactly 1;
            }

            It "Calls 'Set-ADUser' with 'Replace' when existing mismatched AD property is null" {
                $testADPropertyName = 'Title';
                Mock -CommandName Get-ADUser -MockWith {
                    $duffADUser = $fakeADUser.Clone();
                    $duffADUser[$testADPropertyName] = $null;
                    return $duffADUser;
                }
                Mock -CommandName Set-ADUser -ParameterFilter { $Replace.ContainsKey($testADPropertyName) }

                Set-TargetResource @testPresentParams -JobTitle 'Gaffer';

                Assert-MockCalled -CommandName Set-ADUser -ParameterFilter { $Replace.ContainsKey($testADPropertyName) } -Scope It -Exactly 1;
            }

            It "Calls 'Set-ADUser' with 'Replace' when existing mismatched AD property is empty" {
                $testADPropertyName = 'Title';
                Mock -CommandName Get-ADUser -MockWith {
                    $duffADUser = $fakeADUser.Clone();
                    $duffADUser[$testADPropertyName] = '';
                    return $duffADUser;
                }
                Mock -CommandName Set-ADUser -ParameterFilter { $Replace.ContainsKey($testADPropertyName) }

                Set-TargetResource @testPresentParams -JobTitle 'Gaffer';

                Assert-MockCalled -CommandName Set-ADUser -ParameterFilter { $Replace.ContainsKey($testADPropertyName) } -Scope It -Exactly 1;
            }

            It "Calls 'Set-ADUser' with 'Remove' when new mismatched AD property is empty" {
                $testADPropertyName = 'Title';
                Mock -CommandName Get-ADUser -MockWith {
                    $duffADUser = $fakeADUser.Clone();
                    $duffADUser[$testADPropertyName] = 'Incorrect job title';
                    return $duffADUser;
                }
                Mock -CommandName Set-ADUser -ParameterFilter { $Remove.ContainsKey($testADPropertyName) }

                Set-TargetResource @testPresentParams -JobTitle '';

                Assert-MockCalled -CommandName Set-ADUser -ParameterFilter { $Remove.ContainsKey($testADPropertyName) } -Scope It -Exactly 1;
            }

            It "Calls 'Remove-ADUser' when 'Ensure' is 'Absent' and user account exists" {
                Mock -CommandName Get-ADUser -MockWith { return [PSCustomObject] $fakeADUser; }
                Mock -CommandName Remove-ADUser -ParameterFilter { $Identity.ToString() -eq $testAbsentParams.UserName }

                Set-TargetResource @testAbsentParams;

                Assert-MockCalled -CommandName Remove-ADUser -ParameterFilter { $Identity.ToString() -eq $testAbsentParams.UserName } -Scope It
            }

            It 'Calls Restore-AdCommonObject when RestoreFromRecycleBin is used' {
                $restoreParam = $testPresentParams.Clone()
                $restoreParam.RestoreFromRecycleBin = $true
                $script:mockCounter = 0
                Mock -CommandName Get-TargetResource -MockWith {
                    if ($script:mockCounter -gt 0)
                    {
                        return @{Ensure = 'Present'}
                    }
    
                    $script:mockCounter++
                    return @{Ensure = 'Absent'}
                }
                Mock -CommandName Restore-ADCommonObject -MockWith { return [PSCustomObject]@{
                    ObjectClass = 'computer'
                }}
                Mock -CommandName New-ADUser
                Mock -CommandName Set-ADUser -ParameterFilter { $true}
    
                Set-TargetResource @restoreParam
    
                Assert-MockCalled -CommandName Restore-ADCommonObject -Scope It
                Assert-MockCalled -CommandName New-ADUser -Times 0 -Exactly -Scope It
                Assert-MockCalled -CommandName Set-ADUser -Scope It
            }
    
            It 'Calls New-ADUser when RestoreFromRecycleBin is used and if no object was found in the recycle bin' {
                $restoreParam = $testPresentParams.Clone()
                $restoreParam.RestoreFromRecycleBin = $true
                $script:mockCounter = 0
                Mock -CommandName Get-TargetResource -MockWith {
                    if ($script:mockCounter -gt 0)
                    {
                        return @{Ensure = 'Present'}
                    }
    
                    $script:mockCounter++
                    return @{Ensure = 'Absent'}
                }
                Mock -CommandName Restore-ADCommonObject
                Mock -CommandName New-ADUser
                Mock -CommandName Set-ADUser -ParameterFilter { $true}
    
                Set-TargetResource @restoreParam
    
                Assert-MockCalled -CommandName Restore-ADCommonObject -Scope It
                Assert-MockCalled -CommandName New-ADUser -Scope It
                Assert-MockCalled -CommandName Set-ADUser -Scope It
            }
    
            It 'Throws when object cannot be restored from recycle bin' {
                $restoreParam = $testPresentParams.Clone()
                $restoreParam.RestoreFromRecycleBin = $true
                $script:mockCounter = 0
                Mock -CommandName Get-TargetResource -MockWith {
                    if ($script:mockCounter -gt 0)
                    {
                        return @{Ensure = 'Present'}
                    }
    
                    $script:mockCounter++
                    return @{Ensure = 'Absent'}
                }
                Mock -CommandName Restore-ADCommonObject -MockWith {throw (New-Object -TypeName System.InvalidOperationException)}
                Mock -CommandName New-ADUser
                Mock -CommandName Set-ADUser -ParameterFilter { $true}
    
                {Set-TargetResource @restoreParam} | Should -Throw
    
                Assert-MockCalled -CommandName Restore-ADCommonObject -Scope It
                Assert-MockCalled -CommandName New-ADUser -Scope It -Exactly -Times 0
                Assert-MockCalled -CommandName Set-ADUser -Scope It -Exactly -Times 0
            }
        }
        #endregion

        #region Function Assert-TargetResource
        Describe "$($Global:DSCResourceName)\Assert-Parameters" {

            It "Does not throw when 'PasswordNeverExpires' and 'CannotChangePassword' are specified" {
                { Assert-Parameters -PasswordNeverExpires $true -CannotChangePassword $true } | Should Not Throw;
            }

            It "Throws when account is disabled and 'Password' is specified" {
                { Assert-Parameters -Password $testCredential -Enabled $false } | Should Throw;
            }

        }
        #endregion

    }
    #endregion
}
finally
{
    #region FOOTER
    Restore-TestEnvironment -TestEnvironment $TestEnvironment
    #endregion
}


