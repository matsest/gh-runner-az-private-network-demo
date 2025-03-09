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

Describe "Merge-HashTable" {
    It "should merge two hashtables with no overlapping keys" {
        $default = @{ key1 = "value1"; key2 = "value2" }
        $update = @{ key3 = "value3"; key4 = "value4" }
        $result = Merge-HashTable -Default $default -Update $update
        $result["key1"] | Should -Be "value1"
        $result["key2"] | Should -Be "value2"
        $result["key3"] | Should -Be "value3"
        $result["key4"] | Should -Be "value4"
    }

    It "should merge two hashtables with overlapping keys" {
        $default = @{ key1 = "value1"; key2 = "value2" }
        $update = @{ key2 = "new_value2"; key3 = "value3" }
        $result = Merge-HashTable -Default $default -Update $update
        $result["key1"] | Should -Be "value1"
        $result["key2"] | Should -Be "new_value2"
        $result["key3"] | Should -Be "value3"
    }

    It "should return the default hashtable if update is empty" {
        $default = @{ key1 = "value1"; key2 = "value2" }
        $update = @{}
        $result = Merge-HashTable -Default $default -Update $update
        $result["key1"] | Should -Be "value1"
        $result["key2"] | Should -Be "value2"
    }

    It "should return the update hashtable if default is empty" {
        $default = @{}
        $update = @{ key1 = "value1"; key2 = "value2" }
        $result = Merge-HashTable -Default $default -Update $update
        $result["key1"] | Should -Be "value1"
        $result["key2"] | Should -Be "value2"
    }
}