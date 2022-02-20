// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";


contract Vaultable {

    //Libraries
    using SafeMath for uint256;

    struct Vault { 
        uint256 vaultId;
        uint256 vaultValue;
        uint256 unlockBlock;
        address owner;
    }

    //************************************
    // returns all vault information of a vaultIf
    //************************************
    mapping(uint256 => Vault) public vaultOf;

    //************************************
    // returns the total number of existing vaults
    //************************************
    uint256 public vaultCount;

    //************************************
    // returns  cumulative value of all eth in all vaults
    //************************************
    uint256 public  cumulativeVaultValue;


    constructor(){
        vaultCount = 0;
    }


    //************************************
    // _generateNewVault
    // Creates a new sequenced vault
    // Flag determining if a vault is timelocked 
    // Vault value always starts at zero
    //************************************
    function _generateNewVault(address _vaultOwner, bool _isTimeLocked) public returns(Vault memory vault){
        uint256 _vaultId = vaultCount.add(1);
        Vault memory _newVault = _generateNewVaultWithId(_vaultId, _vaultOwner, _isTimeLocked);
        vaultCount = vaultCount.add(1);
        return _newVault;
    }

    //************************************
    // __generateNewVaultWithId
    // Creates a new vault with custom id
    // Flag determining if a vault is timelocked 
    // Vault value always starts at zero
    //************************************
    function _generateNewVaultWithId(uint256 _vaultId, address _vaultOwner, bool _isTimeLocked) internal returns(Vault memory vault){
        uint256 _unlockBlock = generateVaultUnlockBlock(_isTimeLocked);
        Vault memory _newVault = Vault(_vaultId, 0, _unlockBlock, _vaultOwner);
        vaultOf[_vaultId] = _newVault;
        emit VaultCreated(_newVault);
        return _newVault;
    }

    //************************************
    // generateVaultUnlockBlock
    // returns block height at which a vault will be unlocked
    // Flag determining if a vault is timelocked
    // All non timelocked vaults have a unlock block of zero 
    //************************************
    function generateVaultUnlockBlock(bool _isTimeLocked) internal view returns(uint256 num){
        uint256 _unlockBlock = 0;
        if(_isTimeLocked == true) {
            //Notes 1year = 2,102,400  - 2.4 million blocks 
            uint256 _currentBlock = block.number;
            _unlockBlock = _currentBlock.add(2200000);
        }
        return _unlockBlock;
    }


    //************************************
    // _depositToVault
    // requires a vault has an owner
    //************************************
    function _depositToVault(uint256 _vaultId) public payable{
        uint256 value = msg.value;
        require(_vaultHasOwner(_vaultId) == true);
        _handleVaultValueIncrease(_vaultId, value);
    }

    //************************************
    // _vaultHasOwner
    // returns whether a vault has an owner;
    //************************************
    function _vaultHasOwner(uint256 _vaultId) public view returns(bool _hasOwner){
        address _vaultOwner = _ownerOfVault(_vaultId);
        if (_vaultOwner == address(0)){
            return false;
        } else {
            return true;
        }
    }

    //************************************
    // _ownerOfVault
    // returns the owner of any block
    //************************************
    function _ownerOfVault(uint256 _vaultId) public view returns(address _vaultOwner){
        return vaultOf[_vaultId].owner;
    }


    //************************************
    // _handleVaultValueIncrease
    // updates vault value
    // updates cumulative vault value
    //************************************
    function _handleVaultValueIncrease(uint256 _vaultId, uint256 _value) internal {
        _addValueToVault(_vaultId, _value);
        _increaseCumulativeVaultValue(_value);
    }

    //************************************
    // _addValueToVault
    // adds value to a specific vault
    //************************************
    function _addValueToVault(uint256 _vaultId, uint256 _value) private {
        require(_value > 0);
        uint256 _currentValue = vaultOf[_vaultId].vaultValue;
        vaultOf[_vaultId].vaultValue = _currentValue.add(_value);
        emit VaultIncreasedInValue(vaultOf[_vaultId], _value);
    }


    //************************************
    // _increaseCumulativeVaultValue
    // increases cumalativeVaultValue
    //************************************
    function _increaseCumulativeVaultValue(uint256 _value) private {
        require(_value > 0);
        cumulativeVaultValue = cumulativeVaultValue.add(_value);
        emit CumalativeVaultValueIncreasedTo(cumulativeVaultValue);
    }

    //************************************
    // _handleVaultValueDecrease
    // updates vault value
    // updates cumulative vault value
    //************************************
    function _handleVaultValueDecrease(uint256 _vaultId, uint256 _value) internal {
        _decreaseValueFromVault(_vaultId, _value);
        _decreaseCumulativeVaultValue(_value);
    }

    //************************************
    // _decreaseValueFromVault
    // decreases value from a specific vault
    //************************************
    function _decreaseValueFromVault(uint256 _vaultId, uint256 _value) private {
        uint256 _currentValue = vaultOf[_vaultId].vaultValue;
        require(_currentValue >= _value);
        vaultOf[_vaultId].vaultValue = _currentValue.sub(_value);
        emit VaultDecreasedInValue(vaultOf[_vaultId], _value);
    }

    //************************************
    // _decreaseCumulativeVaultValue
    // increases cumalativeVaultValue
    //************************************
    function _decreaseCumulativeVaultValue(uint256 _value) private {
        require(cumulativeVaultValue >= _value);
        cumulativeVaultValue = cumulativeVaultValue.sub(_value);
        emit CumalativeVaultValueDecreasedTo(cumulativeVaultValue);
    }

    //************************************
    // vaultIsUnlocked
    // returns whether a particular block is unlocked or not
    //************************************
    function vaultIsUnlocked(uint256 _vaultId) public view returns(bool isUnlocked){ 
        uint256 _blockNumber = block.number;
        uint256 _unlockBlock = vaultOf[_vaultId].unlockBlock;
        bool _isUnlocked = (_unlockBlock >= _blockNumber);
        return _isUnlocked;
    }

    //////
    //////This needs to be rewritten in a way where the withrawValue is the amount the withdrawer 
    //////wants to recieve PLUS the total gas fees in the transaction. If the total fees PLUS the 
    //////withdraw value are greate than the currentVaultValue then this call should fail. The reasoning
    //////for this is so no ones fees can potentially eat up the total value stored on the contract
    //////
    //////NOTE: This may come for free if the fees are being initiated by the withrawers personal account
    
    //************************************
    // _withdrawFromVault
    // this can only be called from derived contracts
    // responsability of parent contracts to ensure security of this function
    //************************************
    function _withdrawFromVault(uint256 _vaultId, uint256 _withdrawValue, address payable _recipient) internal {
        uint256 _currentVaultValue = vaultOf[_vaultId].vaultValue;
        require(_currentVaultValue >= _withdrawValue);
        bool sent = _recipient.send(_withdrawValue);
        require(sent, "Failed to send Ether");
        _handleVaultValueDecrease(_vaultId, _withdrawValue);
        emit WithdrawFromVault(vaultOf[_vaultId], _withdrawValue, _recipient);
    }

    //************************************
    // _contractProfit
    // Returns the total value of the contract minus the cumulative value of all eth in vaults
    //************************************
    function _contractProfit() public view returns(uint256 _value){
        uint256 _contractValue = _totalContractValue();
        uint256 _profit = _contractValue.sub(cumulativeVaultValue);
        return _profit;
    }

    //************************************
    // _totalContractValue
    // returns the total value locked into the contract in wei
    //************************************
    function _totalContractValue() public view returns(uint256 _value){
        return address(this).balance;
    }


    //************************************
    // _transferVaultOwnership
    // this can only be called from derived contracts
    // responsability of parent contracts to ensure security of this function
    //************************************
    function _transferVaultOwnership(uint256 _vaultId, address _to) internal {
        address _from = vaultOf[_vaultId].owner;
        vaultOf[_vaultId].owner = _to;
        emit VaultTransferedOwnership(vaultOf[_vaultId], _from, _to);
    }



    // must create a fallback that sends any extraneus eth to the owners vault or infers an owners value

    event VaultCreated(Vault vault);
    event VaultDecreasedInValue(Vault vault, uint256 _value);
    event VaultIncreasedInValue(Vault vault, uint256 _value);
    event CumalativeVaultValueIncreasedTo(uint256 _cumalativevalue);
    event CumalativeVaultValueDecreasedTo(uint256 _cumalativevalue);
    event VaultTransferedOwnership(Vault vault, address _from, address _to);
    event WithdrawFromVault(Vault vault, uint256 _withdrawValue, address _recipient);


}