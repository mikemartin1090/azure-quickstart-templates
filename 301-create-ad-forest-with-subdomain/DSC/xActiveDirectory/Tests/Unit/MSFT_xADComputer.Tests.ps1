[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
param()

$Global:DSCModuleName      = 'xActiveDirectory' # Example xNetworking
$Global:DSCResourceName    = 'MSFT_xADComputer' # Example MSFT_xFirewall

#region HEADER
# Unit Test Template Version: 1.1.0
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

    # The InModuleScope command allows you to perform white-box unit testing on the internal
    # (non-exported) code of a Script Module.
    InModuleScope $Global:DSCResourceName {

        $testPresentParams = @{
            ComputerName = 'TESTCOMPUTER';
            Ensure = 'Present';
        }

        $testAbsentParams = $testPresentParams.Clone();
        $testAbsentParams['Ensure'] = 'Absent';

        $fakeADComputer = @{
            DistinguishedName = "CN=$($testPresentParams.ComputerName),CN=Computers,DC=contoso,DC=com";
            Enabled = $true;
            Name = $testPresentParams.ComputerName;
            SamAccountName = '{0}$' -f $testPresentParams.ComputerName;
            SID = 'S-1-5-21-1409167834-891301383-2860967316-1143';
            ObjectClass = 'computer';
            ObjectGUID = [System.Guid]::NewGuid();
            UserPrincipalName = 'TESTCOMPUTER@contoso.com';
            ServicePrincipalNames = @('spn/a','spn/b');
            Location = 'Test location';
            DnsHostName = '{0}.contoso.com' -f $testPresentParams.ComputerName;
            DisplayName = $testPresentParams.ComputerName;
            Description = 'Test description';
            ManagedBy = 'CN=Manager,CN=Users,DC=contoso,DC=com';
        }

        $testDomainController = 'TESTDC';
        $testCredential = [System.Management.Automation.PSCredential]::Empty;

        #region Function Get-TargetResource
        Describe "$($Global:DSCResourceName)\Get-TargetResource" {

            It "Returns a 'System.Collections.Hashtable' object type" {
                Mock -CommandName Get-ADComputer -MockWith { return [PSCustomObject] $fakeADComputer; }

                $adUser = Get-TargetResource @testPresentParams;

                $adUser -is [System.Collections.Hashtable] | Should Be $true;
            }

            It "Returns 'Ensure' is 'Present' when user account exists" {
                Mock -CommandName Get-ADComputer -MockWith { return [PSCustomObject] $fakeADComputer; }

                $adUser = Get-TargetResource @testPresentParams;

                $adUser.Ensure | Should Be 'Present';
            }

            It "Returns 'Ensure' is 'Absent' when user account does not exist" {
                Mock -CommandName Get-ADComputer -MockWith { throw New-Object Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException }

                $adUser = Get-TargetResource @testPresentParams;

                $adUser.Ensure | Should Be 'Absent';
            }

            It "Calls 'Get-ADComputer' with 'Server' parameter when 'DomainController' specified" {
                Mock -CommandName Get-ADComputer -ParameterFilter { $Server -eq $testDomainController } -MockWith { return [PSCustomObject] $fakeADComputer; }

                Get-TargetResource @testPresentParams -DomainController $testDomainController;

                Assert-MockCalled -CommandName Get-ADComputer -ParameterFilter { $Server -eq $testDomainController } -Scope It
            }

            It "Calls 'Get-ADComputer' with 'Credential' parameter when 'DomainAdministratorCredential' specified" {
                Mock -CommandName Get-ADComputer -ParameterFilter { $Credential -eq $testCredential } -MockWith { return [PSCustomObject] $fakeADComputer; }

                Get-TargetResource @testPresentParams -DomainAdministratorCredential $testCredential;

                Assert-MockCalled -CommandName Get-ADComputer -ParameterFilter { $Credential -eq $testCredential } -Scope It
            }

        }
        #endregion

        #region Function Test-TargetResource
        Describe "$($Global:DSCResourceName)\Test-TargetResource" {

            $testStringProperties = @(
                'Location',
                'DnsHostName',
                'UserPrincipalName',
                'DisplayName',
                'Path',
                'Description',
                'Manager'
            );
            $testArrayProperties = @(
                'ServicePrincipalNames'
            );
            $testBooleanProperties = @(
                'Enabled'
            );

            It "Passes when computer account does not exist and 'Ensure' is 'Absent'" {
                Mock -CommandName Get-TargetResource -MockWith { return $testAbsentParams }

                Test-TargetResource @testAbsentParams | Should Be $true;
            }

            It "Passes when computer account exists and 'Ensure' is 'Present'" {
                Mock -CommandName Get-TargetResource -MockWith { return $testPresentParams }

                Test-TargetResource @testPresentParams | Should Be $true;
            }

            It "Fails when computer account does not exist and 'Ensure' is 'Present'" {
                Mock -CommandName Get-TargetResource -MockWith { return $testAbsentParams }

                Test-TargetResource @testPresentParams | Should Be $false;
            }

            It "Fails when computer account exists, and 'Ensure' is 'Absent'" {
                Mock -CommandName Get-TargetResource -MockWith { return $testPresentParams }

                Test-TargetResource @testAbsentParams | Should Be $false;
            }

            foreach ($testParameter in $testStringProperties) {

                It "Passes when computer account '$testParameter' matches AD account property" {
                    $testParameterValue = 'Test Parameter String Value';
                    $testValidPresentParams = $testPresentParams.Clone();
                    $testValidPresentParams[$testParameter] = $testParameterValue;
                    $validADComputer = $testPresentParams.Clone();
                    Mock -CommandName Get-TargetResource -MockWith {
                        $validADComputer[$testParameter] = $testParameterValue;
                        return $validADComputer;
                    }

                    Test-TargetResource @testValidPresentParams | Should Be $true;
                }

                It "Fails when computer account '$testParameter' does not match incorrect AD account property value" {
                    $testParameterValue = 'Test Parameter String Value';
                    $testValidPresentParams = $testPresentParams.Clone();
                    $testValidPresentParams[$testParameter] = $testParameterValue;
                    $invalidADComputer = $testPresentParams.Clone();
                    Mock -CommandName Get-TargetResource -MockWith {
                        $invalidADComputer[$testParameter] = $testParameterValue.Substring(0, ([System.Int32] $testParameterValue.Length/2));
                        return $invalidADComputer;
                    }

                    Test-TargetResource @testValidPresentParams | Should Be $false;
                }

                It "Fails when computer account '$testParameter' does not match empty AD account property value" {
                    $testParameterValue = 'Test Parameter String Value';
                    $testValidPresentParams = $testPresentParams.Clone();
                    $testValidPresentParams[$testParameter] = $testParameterValue;
                    $invalidADComputer = $testPresentParams.Clone();
                    Mock -CommandName Get-TargetResource -MockWith {
                        $invalidADComputer[$testParameter] = '';
                        return $invalidADComputer;
                    }

                    Test-TargetResource @testValidPresentParams | Should Be $false;
                }

                It "Fails when computer account '$testParameter' does not match null AD account property value" {
                    $testParameterValue = 'Test Parameter String Value';
                    $testValidPresentParams = $testPresentParams.Clone();
                    $testValidPresentParams[$testParameter] = $testParameterValue;
                    $invalidADComputer = $testPresentParams.Clone();
                    Mock -CommandName Get-TargetResource -MockWith {
                        $invalidADComputer[$testParameter] = $null;
                        return $invalidADComputer;
                    }

                    Test-TargetResource @testValidPresentParams | Should Be $false;
                }

                It "Passes when empty computer account '$testParameter' matches empty AD account property" {
                    $testValidPresentParams = $testPresentParams.Clone();
                    $testValidPresentParams[$testParameter] = $testParameterValue;
                    $validADComputer = $testPresentParams.Clone();
                    Mock -CommandName Get-TargetResource -MockWith {
                        $validADComputer[$testParameter] = '';
                        return $validADComputer;
                    }

                    Test-TargetResource @testValidPresentParams | Should Be $true;
                }

                It "Passes when empty computer account '$testParameter' matches null AD account property" {
                    $testValidPresentParams = $testPresentParams.Clone();
                    $testValidPresentParams[$testParameter] = $testParameterValue;
                    $validADComputer = $testPresentParams.Clone();
                    Mock -CommandName Get-TargetResource -MockWith {
                        $validADComputer[$testParameter] = $null;
                        return $validADComputer;
                    }

                    Test-TargetResource @testValidPresentParams | Should Be $true;
                }

            } #end foreach test string property

            foreach ($testParameter in $testArrayProperties) {

                It "Passes when computer account '$testParameter' matches empty AD account property" {
                    $testParameterValue = @();
                    $testValidPresentParams = $testPresentParams.Clone();
                    $testValidPresentParams[$testParameter] = $testParameterValue;
                    $validADComputer = $testPresentParams.Clone();
                    Mock -CommandName Get-TargetResource -MockWith {
                        $validADComputer[$testParameter] = $testParameterValue;
                        return $validADComputer;
                    }

                    Test-TargetResource @testValidPresentParams | Should Be $true;
                }

                It "Passes when computer account '$testParameter' matches single AD account property" {
                    $testParameterValue = @('Entry1');
                    $testValidPresentParams = $testPresentParams.Clone();
                    $testValidPresentParams[$testParameter] = $testParameterValue;
                    $validADComputer = $testPresentParams.Clone();
                    Mock -CommandName Get-TargetResource -MockWith {
                        $validADComputer[$testParameter] = $testParameterValue;
                        return $validADComputer;
                    }

                    Test-TargetResource @testValidPresentParams | Should Be $true;
                }

                It "Passes when computer account '$testParameter' matches multiple AD account property" {
                    $testParameterValue = @('Entry1','Entry2');
                    $testValidPresentParams = $testPresentParams.Clone();
                    $testValidPresentParams[$testParameter] = $testParameterValue;
                    $validADComputer = $testPresentParams.Clone();
                    Mock -CommandName Get-TargetResource -MockWith {
                        $validADComputer[$testParameter] = $testParameterValue;
                        return $validADComputer;
                    }

                    Test-TargetResource @testValidPresentParams | Should Be $true;
                }

                It "Fails when computer account '$testParameter' does not match AD account property count" {
                    $testParameterValue = @('Entry1','Entry2');
                    $testValidPresentParams = $testPresentParams.Clone();
                    $testValidPresentParams[$testParameter] = $testParameterValue;
                    $validADComputer = $testPresentParams.Clone();
                    Mock -CommandName Get-TargetResource -MockWith {
                        $validADComputer[$testParameter] = @('Entry1');
                        return $validADComputer;
                    }

                    Test-TargetResource @testValidPresentParams | Should Be $false;
                }

                It "Fails when computer account '$testParameter' does not match AD account property name" {
                    $testParameterValue = @('Entry1');
                    $testValidPresentParams = $testPresentParams.Clone();
                    $testValidPresentParams[$testParameter] = $testParameterValue;
                    $validADComputer = $testPresentParams.Clone();
                    Mock -CommandName Get-TargetResource -MockWith {
                        $validADComputer[$testParameter] = @('Entry2');
                        return $validADComputer;
                    }

                    Test-TargetResource @testValidPresentParams | Should Be $false;
                }

                It "Fails when computer account '$testParameter' does not match empty AD account property" {
                    $testParameterValue = @('Entry1');
                    $testValidPresentParams = $testPresentParams.Clone();
                    $testValidPresentParams[$testParameter] = $testParameterValue;
                    $validADComputer = $testPresentParams.Clone();
                    Mock -CommandName Get-TargetResource -MockWith {
                        $validADComputer[$testParameter] = @();
                        return $validADComputer;
                    }

                    Test-TargetResource @testValidPresentParams | Should Be $false;
                }

                It "Fails when empty computer account '$testParameter' does not match AD account property" {
                    $testParameterValue = @();
                    $testValidPresentParams = $testPresentParams.Clone();
                    $testValidPresentParams[$testParameter] = $testParameterValue;
                    $validADComputer = $testPresentParams.Clone();
                    Mock -CommandName Get-TargetResource -MockWith {
                        $validADComputer[$testParameter] = @('ExtraEntry1');
                        return $validADComputer;
                    }

                    Test-TargetResource @testValidPresentParams | Should Be $false;
                }

            } #end foreach test string property

            foreach ($testParameter in $testBooleanProperties) {

                It "Passes when computer account '$testParameter' matches AD account property" {
                    $testParameterValue = $true;
                    $testValidPresentParams = $testPresentParams.Clone();
                    $testValidPresentParams[$testParameter] = $testParameterValue;
                    $validADComputer = $testPresentParams.Clone();
                    Mock -CommandName Get-TargetResource -MockWith {
                        $validADComputer[$testParameter] = $testParameterValue;
                        return $validADComputer;
                    }

                    Test-TargetResource @testValidPresentParams | Should Be $true;
                }

                It "Fails when computer account '$testParameter' does not match AD account property value" {
                    $testParameterValue = $true;
                    $testValidPresentParams = $testPresentParams.Clone();
                    $testValidPresentParams[$testParameter] = $testParameterValue;
                    $invalidADComputer = $testPresentParams.Clone();
                    Mock -CommandName Get-TargetResource -MockWith {
                        $invalidADComputer[$testParameter] = -not $testParameterValue;
                        return $invalidADComputer;
                    }

                    Test-TargetResource @testValidPresentParams | Should Be $false;
                }

            } #end foreach test boolean property

        }
        #endregion

        #region Function Set-TargetResource
        Describe "$($Global:DSCResourceName)\Set-TargetResource" {

            $testStringProperties = @(
                'Location',
                'DnsHostName',
                'UserPrincipalName',
                'DisplayName',
                'Description'
                # Manager is translated to ManagedBy
            );

            $testArrayProperties = @(
                'ServicePrincipalNames'
            );
            $testBooleanProperties = @(
                'Enabled'
            );

            It "Calls 'New-ADComputer' when 'Ensure' is 'Present' and the account does not exist" {
                $newComputerName = 'NEWCOMPUTER'
                $newAbsentParams = $testAbsentParams.Clone();
                $newAbsentParams['ComputerName'] = $newComputerName;
                $newPresentParams = $testPresentParams.Clone();
                $newPresentParams['ComputerName'] = $newComputerName;
                Mock -CommandName New-ADComputer -ParameterFilter { $Name -eq $newComputerName }
                Mock -CommandName Set-ADComputer
                Mock -CommandName Get-TargetResource -ParameterFilter { $ComputerName -eq $newComputerName } -MockWith { return $newAbsentParams; }

                Set-TargetResource @newPresentParams;

                Assert-MockCalled -CommandName New-ADComputer -ParameterFilter { $Name -eq $newComputerName } -Scope It
            }

            It "Calls 'New-ADComputer' when 'Ensure' is 'Present' and the account does not exist, RequestFile is set, DJOIN OK" {
                $newComputerName = 'NEWCOMPUTER'
                $newAbsentParams = $testAbsentParams.Clone();
                $newAbsentParams['ComputerName'] = $newComputerName;
                $newPresentParams = $testPresentParams.Clone();
                $newPresentParams['ComputerName'] = $newComputerName;
                $newPresentParams['RequestFile'] = 'c:\ODJTest.txt';
                Mock -CommandName New-ADComputer -ParameterFilter { $Name -eq $newComputerName }
                Mock -CommandName djoin.exe -MockWith { $LASTEXITCODE = 0; 'OK' }
                Mock -CommandName Set-ADComputer
                Mock -CommandName Get-TargetResource -ParameterFilter { $ComputerName -eq $newComputerName } -MockWith { return $newAbsentParams; }

                Set-TargetResource @newPresentParams;

                Assert-MockCalled -CommandName New-ADComputer -ParameterFilter { $Name -eq $newComputerName } -Scope It -Exactly 0;
                Assert-MockCalled -CommandName djoin.exe -Exactly 1;
            }

            It "Calls 'New-ADComputer' with 'Path' when specified" {
                $newComputerName = 'NEWCOMPUTER'
                $newAbsentParams = $testAbsentParams.Clone();
                $newAbsentParams['ComputerName'] = $newComputerName;
                $newPresentParams = $testPresentParams.Clone();
                $newPresentParams['ComputerName'] = $newComputerName;
                $targetPath = 'OU=Test,DC=contoso,DC=com';
                Mock -CommandName New-ADComputer -ParameterFilter { $Path -eq $targetPath }
                Mock -CommandName Set-ADComputer
                Mock -CommandName Get-TargetResource -ParameterFilter { $ComputerName -eq $newComputerName } -MockWith { return $newAbsentParams; }

                Set-TargetResource @newPresentParams -Path $targetPath;

                Assert-MockCalled -CommandName New-ADComputer -ParameterFilter { $Path -eq $targetPath } -Scope It
            }

            It "Calls 'Move-ADObject' when 'Ensure' is 'Present', the computer account exists but Path is incorrect" {
                $testTargetPath = 'OU=NewPath,DC=contoso,DC=com';
                Mock -CommandName Set-ADComputer
                Mock -CommandName Get-ADComputer -MockWith {
                    $duffADComputer = $fakeADComputer.Clone();
                    $duffADComputer['DistinguishedName'] = 'CN={0},OU=WrongPath,DC=contoso,DC=com' -f $testPresentParams.ComputerName;
                    return $duffADComputer;
                }
                Mock -CommandName Move-ADObject -ParameterFilter { $TargetPath -eq $testTargetPath }

                Set-TargetResource @testPresentParams -Path $testTargetPath;

                Assert-MockCalled -CommandName Move-ADObject -ParameterFilter { $TargetPath -eq $testTargetPath } -Scope It
            }

            foreach ($testParameter in $testStringProperties) {

                It "Calls 'Set-ADComputer' with 'Remove' when '$testParameter' is `$null" {
                    Mock -CommandName Get-ADComputer -MockWith { return $fakeADComputer; }
                    Mock -CommandName Set-ADComputer -ParameterFilter { $Remove.ContainsKey($testParameter) }

                    $setTargetResourceParams = $testPresentParams.Clone();
                    $setTargetResourceParams[$testParameter] = '';
                    Set-TargetResource @setTargetResourceParams;

                    Assert-MockCalled -CommandName Set-ADComputer -ParameterFilter { $Remove.ContainsKey($testParameter) } -Scope It -Exactly 1;
                }

                It "Calls 'Set-ADComputer' with 'Replace' when existing '$testParameter' is not `$null" {
                    Mock -CommandName Get-ADComputer -MockWith { return $fakeADComputer; }
                    Mock -CommandName Set-ADComputer -ParameterFilter { $Replace.ContainsKey($testParameter) }

                    $setTargetResourceParams = $testPresentParams.Clone();
                    $setTargetResourceParams[$testParameter] = 'NewStringValue';
                    Set-TargetResource @setTargetResourceParams;

                    Assert-MockCalled -CommandName Set-ADComputer -ParameterFilter { $Replace.ContainsKey($testParameter) } -Scope It -Exactly 1;
                }

            } #end foreach string parameter

            It "Calls 'Set-ADComputer' with 'Remove' when 'Manager' is `$null" {
                ## Manager translates to AD attribute 'managedBy'
                Mock -CommandName Get-ADComputer -MockWith { return $fakeADComputer; }
                Mock -CommandName Set-ADComputer -ParameterFilter { $Remove.ContainsKey('ManagedBy') }

                $setTargetResourceParams = $testPresentParams.Clone();
                $setTargetResourceParams['Manager'] = '';
                Set-TargetResource @setTargetResourceParams;

                Assert-MockCalled -CommandName Set-ADComputer -ParameterFilter { $Remove.ContainsKey('ManagedBy') } -Scope It -Exactly 1;
            }

            It "Calls 'Set-ADComputer' with 'Replace' when existing 'Manager' is not `$null" {
                ## Manager translates to AD attribute 'managedBy'
                Mock -CommandName Get-ADComputer -MockWith { return $fakeADComputer; }
                Mock -CommandName Set-ADComputer -ParameterFilter { $Replace.ContainsKey('ManagedBy') }

                $setTargetResourceParams = $testPresentParams.Clone();
                $setTargetResourceParams['Manager'] = 'NewValue';
                Set-TargetResource @setTargetResourceParams;

                Assert-MockCalled -CommandName Set-ADComputer -ParameterFilter { $Replace.ContainsKey('ManagedBy') } -Scope It -Exactly 1;
            }

            It "Calls 'Set-ADComputer' with 'Enabled' = 'True' by default" {
                Mock -CommandName Get-ADComputer -MockWith { return $fakeADComputer; }
                Mock -CommandName Set-ADComputer -ParameterFilter { $Enabled -eq $true }

                $setTargetResourceParams = $testPresentParams.Clone();
                $setTargetResourceParams[$testParameter] = -not $fakeADComputer.$testParameter;
                Set-TargetResource @setTargetResourceParams;

                Assert-MockCalled -CommandName Set-ADComputer -ParameterFilter { $Enabled -eq $true } -Scope It -Exactly 1;
            }

            It "Calls 'Set-ADComputer' with 'ServicePrincipalNames' when specified" {
                $testSPNs = @('spn/a','spn/b');
                Mock -CommandName Get-ADComputer -MockWith { return $fakeADComputer; }
                Mock -CommandName Set-ADComputer -ParameterFilter { $Replace.ContainsKey('ServicePrincipalName') }

                Set-TargetResource @testPresentParams -ServicePrincipalNames $testSPNs;

                Assert-MockCalled -CommandName Set-ADComputer -ParameterFilter { $Replace.ContainsKey('ServicePrincipalName') } -Scope It -Exactly 1;
            }

            It "Calls 'Remove-ADComputer' when 'Ensure' is 'Absent' and computer account exists" {
                Mock -CommandName Get-ADComputer -MockWith { return $fakeADComputer; }
                Mock -CommandName Remove-ADComputer -ParameterFilter { $Identity.ToString() -eq $testAbsentParams.ComputerName }

                Set-TargetResource @testAbsentParams;

                Assert-MockCalled -CommandName Remove-ADComputer -ParameterFilter { $Identity.ToString() -eq $testAbsentParams.ComputerName } -Scope It
            }

            It 'Should call Restore-AdCommonObject when RestoreFromRecycleBin is used' {
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
                Mock -CommandName New-ADComputer
                 # Had to overwrite parameter filter from an earlier test
                Mock -CommandName Set-ADComputer -ParameterFilter { $true }

                Set-TargetResource @restoreParam

                Assert-MockCalled -CommandName Restore-ADCommonObject -Exactly -Times 1 -Scope It
                Assert-MockCalled -CommandName New-ADComputer -Times 0 -Exactly -Scope It
                Assert-MockCalled -CommandName Set-ADComputer -Exactly -Times 1 -Scope It
            }

            It 'Should call New-ADComputer when RestoreFromRecycleBin is used and if no object was found in the recycle bin' {
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
                Mock -CommandName New-ADComputer
                # Had to overwrite parameter filter from an earlier test
                Mock -CommandName Set-ADComputer -ParameterFilter { $true }

                Set-TargetResource @restoreParam

                Assert-MockCalled -CommandName Restore-ADCommonObject -Exactly -Times 1 -Scope It
                Assert-MockCalled -CommandName New-ADComputer -Exactly -Times 1 -Scope It
                Assert-MockCalled -CommandName Set-ADComputer -Exactly -Times 1 -Scope It
            }

            It 'Should throw the correct error when object cannot be restored from recycle bin' {
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
                Mock -CommandName New-ADComputer
                # Had to overwrite parameter filter from an earlier test
                Mock -CommandName Set-ADComputer -ParameterFilter { $true }

                {Set-TargetResource @restoreParam} | Should -Throw -ExceptionType ([System.InvalidOperationException])

                Assert-MockCalled -CommandName Restore-ADCommonObject -Scope It -Exactly -Times 1
                Assert-MockCalled -CommandName New-ADComputer -Scope It -Exactly -Times 0
                Assert-MockCalled -CommandName Set-ADComputer -Scope It -Exactly -Times 0
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
