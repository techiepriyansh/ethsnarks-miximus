/*    
Copyright 2019 to the Miximus Authors

This file is part of Miximus.

Miximus is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Miximus is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Miximus.  If not, see <https://www.gnu.org/licenses/>.
*/

pragma solidity ^0.5.0;

import "../../ethsnarks/contracts/Verifier.sol";
import "../../ethsnarks/contracts/MerkleTree.sol";
import "../../ethsnarks/contracts/MiMC.sol";


contract Miximus
{
    using MerkleTree for MerkleTree.Data;

    uint constant public AMOUNT = 1 ether;

    mapping (uint256 => bool) public nullifiers;

    MerkleTree.Data internal tree;


    function GetRoot()
        public view returns (uint256)
    {
        return tree.GetRoot();
    }


    /**
    * Returns leaf offset
    */
    function Deposit(uint256 leaf)
        public payable returns (uint256 new_root, uint256 new_offset)
    {
        require( msg.value == AMOUNT );

        return tree.Insert(leaf);
    }


    function MakeLeafHash(uint256 secret, uint256 nullifier)
        public pure returns (uint256)
    {
        // TODO: only need to hash the secret
        uint256[] memory vals = new uint256[](2);

        vals[0] = secret;
        vals[1] = nullifier;
        uint256 spend_hash = MiMC.Hash(vals);

        vals[0] = nullifier;
        vals[1] = spend_hash;
        return MiMC.Hash(vals);
    }


    function GetPath(uint256 leaf)
        public view returns (uint256[29] memory out_path, bool[29] memory out_addr)
    {
        return tree.GetProof(leaf);
    }


    function GetExtHash()
        public view returns (uint256)
    {
        return uint256(sha256(
            abi.encodePacked(
                address(this),
                msg.sender
            ))) % Verifier.ScalarField();
    }


    function IsSpent(uint256 nullifier)
        public view returns (bool)
    {
        return nullifiers[nullifier];
    }


    /**
    * Condense multiple public inputs down to a single one to be provided to the zkSNARK circuit
    */
    function HashPublicInputs( uint256 in_root, uint256 in_nullifier, uint256 in_exthash )
        public pure returns (uint256)
    {
        uint256[] memory inputs_to_hash = new uint256[](3);

        inputs_to_hash[0] = in_root;
        inputs_to_hash[1] = in_nullifier;
        inputs_to_hash[2] = in_exthash;

        return MiMC.Hash(inputs_to_hash);
    }


    function VerifyProof( uint256 in_root, uint256 in_nullifier, uint256 in_exthash, uint256[8] memory proof )
        public view returns (bool)
    {
        uint256[] memory snark_input = new uint256[](1);
        snark_input[0] = HashPublicInputs(in_root, in_nullifier, in_exthash);

        uint256[14] memory vk;
        uint256[] memory vk_gammaABC;
        (vk, vk_gammaABC) = GetVerifyingKey();

        return Verifier.Verify( vk, vk_gammaABC, proof, snark_input );
    }


    function Withdraw(
        uint256 in_root,
        uint256 in_nullifier,
        uint256[8] memory proof
    )
        public
    {
        require( false == nullifiers[in_nullifier] );

        bool is_valid = VerifyProof(in_root, in_nullifier, GetExtHash(), proof);

        require( is_valid );

        nullifiers[in_nullifier] = true;

        msg.sender.transfer(AMOUNT);
    }


    function GetVerifyingKey ()
        public view returns (uint256[14] memory out_vk, uint256[] memory out_gammaABC);
}
