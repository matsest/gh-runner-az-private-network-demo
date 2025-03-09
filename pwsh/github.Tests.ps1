$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module "$here/github.psm1" -Force

Describe "Convert-SubnetSizeToRunnersCount" {
    It "should return the correct number of runners for /24 subnet" {
        $result = Convert-SubnetSizeToRunnersCount -SubnetAddressPrefix "192.168.1.0/24"
        $result | Should -Be 193
    }

    It "should return the correct number of runners for /25 subnet" {
        $result = Convert-SubnetSizeToRunnersCount -SubnetAddressPrefix "192.168.1.0/25"
        $result | Should -Be 94
    }

    It "should return the correct number of runners for /26 subnet" {
        $result = Convert-SubnetSizeToRunnersCount -SubnetAddressPrefix "192.168.1.0/26"
        $result | Should -Be 45
    }

    It "should return the correct number of runners for /27 subnet" {
        $result = Convert-SubnetSizeToRunnersCount -SubnetAddressPrefix "192.168.1.0/27"
        $result | Should -Be 20
    }

    It "should return the correct number of runners for /28 subnet" {
        $result = Convert-SubnetSizeToRunnersCount -SubnetAddressPrefix "192.168.1.0/28"
        $result | Should -Be 8
    }

    It "should throw an error for too small (/29) subnet" {
        { Convert-SubnetSizeToRunnersCount -SubnetAddressPrefix "192.168.1.0/29" -ErrorAction Stop } | Should -Throw
    }

    It "should throw an error for non-valid subnet" {
        { Convert-SubnetSizeToRunnersCount -SubnetAddressPrefix "192.168.1.0/23" -ErrorAction Stop } | Should -Throw
    }
}
