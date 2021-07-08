pragma solidity 0.6.12;

import "ds-test/test.sol";
import { DSValue } from "ds-value/value.sol";
import { OSMock }  from "./test/osmock.sol";

import { SLOSM }   from "./slosm.sol";

interface Hevm {
    function warp(uint256) external;
}

contract SLOSMTest is DSTest {
    Hevm hevm;

    DSValue feed;
    OSMock  osm;
    SLOSM   slosm;
    address bud;

    function setUp() public {
        feed = new DSValue();                                    //create new feed
        feed.poke(bytes32(uint(100 ether)));                     //set feed to 100
        osm = new OSMock(address(feed));                         //create parent osm
        slosm = new SLOSM(address(osm), 3 hours);                //create new osm linked to feed
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D); //get hevm instance
        hevm.warp(uint(slosm.hop()));                            //warp 1 hop

        osm.poke();
        osm.kiss(address(slosm));

        slosm.poke();                                            //set new next osm value
        bud = address(this);                                     //authorized reader
    }

    function testChangeValue() public {
        assertEq(slosm.src(), address(feed));                     //verify slosm source is feed
        assertEq(address(slosm.osm()), address(osm));             //verify slosm osm is osm
        DSValue feed2 = new DSValue();                            //create new feed
        osm.change(address(feed2));                               //change osm source to new feed
        assertEq(slosm.src(), address(feed2));                    //verify osm source is new feed
    }

    function testFailChangeValue() public {
        assertEq(slosm.src(), address(feed));                     //verify slosm source is feed
        assertEq(address(slosm.osm()), address(osm));             //verify slosm osm is osm
        DSValue feed2 = new DSValue();                            //create new feed
        slosm.change(address(feed2));                             //fail when attempting to change directly on slosm
    }

    function testSetHop() public {
        assertEq(uint(slosm.hop()), 3 hours);                     //verify interval is 3 hours
        slosm.step(uint16(2 hours));                              //change interval to 2 hours
        assertEq(uint(slosm.hop()), 2 hours);                     //verify interval is 2 hours
    }

    function testFailSetHopZero() public {
        slosm.step(uint16(0));                                    //attempt to change interval to 0
    }

    function testVoid() public {
        assertTrue(slosm.stopped() == 0);                         //verify osm is active
        osm.kiss(bud);                                            //whitelist caller
        hevm.warp(uint(slosm.hop() * 2));                         //warp 2 hops
        slosm.poke();                                             //set new curent and next osm value
        (bytes32 val, bool has) = slosm.peek();                   //pull current osm value
        assertEq(uint(val), 100 ether);                           //verify osm value is 100
        assertTrue(has);                                          //verify osm value is valid
        (val, has) = slosm.peep();                                //pull next osm value
        assertEq(uint(val), 100 ether);                           //verify next osm value is 100
        assertTrue(has);                                          //verify next osm value is valid
        slosm.void();                                             //void all osm values
        assertTrue(slosm.stopped() == 1);                         //verify osm is inactive
        (val, has) = slosm.peek();                                //pull current osm value
        assertEq(uint(val), 0);                                   //verify current osm value is 0
        assertTrue(!has);                                         //verify current osm value is invalid
        (val, has) = slosm.peep();                                //pull next osm value
        assertEq(uint(val), 0);                                   //verify next osm value is 0
        assertTrue(!has);                                         //verify next osm value is invalid
    }

    function testPoke() public {
        hevm.warp(uint(block.timestamp + slosm.hop()));
        osm.poke();
        slosm.poke();
        feed.poke(bytes32(uint(101 ether)));                      //set new feed value
        hevm.warp(uint(block.timestamp + slosm.hop() * 2));       //warp 2 hops
        osm.poke();                                               //set new current and next osm value
        slosm.poke();                                             //set new current and next osm value
        osm.kiss(bud);                                            //whitelist caller
        (bytes32 val, bool has) = slosm.peek();                   //pull current osm value
        assertEq(uint(val), 100 ether);                           //verify current osm value is 100
        assertTrue(has);                                          //verify current osm value is valid
        (val, has) = osm.peep();                                  //pull next osm value
        assertEq(uint(val), 101 ether);                           //verify next osm value is 101
        assertTrue(has);                                          //verify next osm value is valid
        (val, has) = slosm.peep();                                //pull next osm value
        assertEq(uint(val), 101 ether);                           //verify next osm value is 101
        assertTrue(has);                                          //verify next osm value is valid
        hevm.warp(uint(block.timestamp + slosm.hop() * 2));       //warp 2 hops
        osm.poke();                                               //set new current and next osm value
        slosm.poke();                                             //set new current and next osm value
        (val, has) = osm.peek();                                  //pull current osm value
        assertEq(uint(val), 101 ether);                           //verify current osm value is 101
        assertTrue(has);                                          //verify current osm value is valid
        (val, has) = slosm.peek();                                //pull current osm value
        assertEq(uint(val), 101 ether);                           //verify current osm value is 101
        assertTrue(has);                                          //verify current osm value is valid
    }

    function testFailPoke() public {
        feed.poke(bytes32(uint(101 ether)));                    //set new current and next osm value
        hevm.warp(uint(slosm.hop() * 2 - 1));                   //warp 2 hops - 1 second
        osm.poke();
        slosm.poke();                                           //attempt to set new current and next osm value
        revert(); // FIXME
    }

    function testFailWhitelistPeep() public view {
        slosm.peep();                                           //attempt to pull next osm value
    }

    function testWhitelistPeep() public {
        osm.kiss(bud);                                          //whitelist caller
        (bytes32 val, bool has) = slosm.peep();                 //pull next osm value
        assertEq(uint(val), 100 ether);                         //verify next osm value is 100
        assertTrue(has);                                        //verify next osm value is valid
    }

    function testFailWhitelistPeek() public view {
        slosm.peek();                                           //attempt to pull current osm value
    }

    function testWhitelistPeek() public {
        osm.kiss(bud);                                          //whitelist caller
        slosm.peek();                                           //pull current osm value

    }

    function testKiss() public {
        assertTrue(slosm.bud(address(this)) == 0);              //verify caller is not whitelisted
        osm.kiss(bud);                                          //whitelist caller
        assertTrue(slosm.bud(address(this)) == 1);              //verify caller is whitelisted
    }

    function testDiss() public {
        osm.kiss(bud);                                          //whitelist caller
        assertTrue(slosm.bud(address(this)) == 1);              //verify caller is whitelisted
        osm.diss(bud);                                          //remove caller from whitelist
        assertTrue(slosm.bud(address(this)) == 0);              //verify caller is not whitelisted
    }

    function testStoppedOSM() public {
        osm.stop();
        assertTrue(slosm.stopped() == 1);

        osm.start();
        assertTrue(slosm.stopped() == 0);
    }

    function testStoppedSLOSM() public {
        slosm.stop();
        assertTrue(slosm.stopped() == 1);

        slosm.start();
        assertTrue(slosm.stopped() == 0);
    }
}
