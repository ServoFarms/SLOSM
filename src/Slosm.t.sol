pragma solidity ^0.6.7;

import "ds-test/test.sol";

import "./Slosm.sol";

contract SlosmTest is DSTest {
    Slosm slosm;

    function setUp() public {
        slosm = new Slosm();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
