// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

library Random {
    
    //https://stackoverflow.com/questions/48848948/how-to-generate-a-random-number-in-solidity
    function randomHash() private view returns (uint) {
        uint ranHash = uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));
        return ranHash;
    }

    
    function ranNumBetweenZeroAndX(uint _x) private view returns (uint){
       return randomHash() % _x;
    }

    function ranNumIsLessThanThreshold(uint256 _max, uint256 _threshold) private view returns (bool){
        uint256 ranNum = ranNumBetweenZeroAndX(_max);
        return ranNum < _threshold;
    }
    
}