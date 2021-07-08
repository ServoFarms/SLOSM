pragma solidity 0.6.12;

import "ds-test/test.sol";

import "./slosm.sol";

contract SLOSMTest is DSTest {
    SLOSM  slosm;

    function setUp() public {

        slosm = new SLOSM(address(1), 3 * 60 * 60);
    }


}
