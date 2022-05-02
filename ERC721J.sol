// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;


import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/utils/Context.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/utils/introspection/ERC165.sol';
import "@openzeppelin/contracts/access/Ownable.sol";


error ApprovalCallerNotOwnerNorApproved();
error ApprovalQueryForNonexistentToken();
error ApprovalToCurrentOwner();
error BalanceQueryForZeroAddress();
error MaxCopiesReached();
error MintToZeroAddress();
error NotEnoughEther();
error OwnerIndexOutOfBounds();
error OwnerIsOperator();
error OwnerQueryForNonexistentToken();
error QueryForNonexistentToken();
error SenderNotOwner();
error TokenAlreadyMinted();
error TokenIndexOutOfBounds();
error TransferCallerNotOwnerNorApproved();
error TransferFromIncorrectOwner();
error TransferToNonERC721ReceiverImplementer();
error TransferToZeroAddress();
error URIQueryForNonexistentToken();
error URISetOfNonexistentSong();

//
//Version 1 of ERC721J
//
//Supports 1/1 original turning into 100.
//Minting a copy requires the owner to own a copy.
//
//More features coming in v2! Stay tuned!
//
contract ERC721J is Context, ERC165, IERC721, IERC721Metadata,
IERC721Enumerable, Ownable {
    using Address for address;
    using Strings for uint256;
    // _tokenIds and _songIds for keeping track of the ongoing total tokenids, and total songids
    uint256 private _tokenIds;
    uint256 private _songIds;


    // Token name
    string private _name = "ERC721J";

    // Token symbol
    string private _symbol = "721J";

    struct tokenInfo {
    uint128 song;
    uint128 serial;
    }


    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;


    // Mapping for song URIs. Takes songId then songEdition into a string.
    mapping(uint256 => string) private _songURIs;
    // Mapping for the counters of songs minted for each song
    mapping(uint256 => uint256) private _songSerials;
    // Mapping for the extra info to each tokenId
    mapping(uint256 => tokenInfo) private _tokenIdInfo;



      //from erc721enumerable
      //
      //function returns the total supply of tokens minted by the contract
      function totalSupply() public view virtual override returns (uint256) {
          return _tokenIds;
      }

      function tokenByIndex(uint256 index) public view override returns (uint256) {
          if (index > _tokenIds) revert TokenIndexOutOfBounds();
          return index;
      }

      function tokenOfOwnerByIndex(address owner, uint256 index) public view override returns (uint256) {
          if (index > balanceOf(owner)) revert OwnerIndexOutOfBounds();
          uint256 numMintedSoFar = _tokenIds;
          uint256 tokenIdsIdx;
          address currOwnershipAddr;
          unchecked {
              for (uint256 i; i <= numMintedSoFar; i++) {
                  address ownership = _owners[i];
                  if (ownership != address(0)) {
                      currOwnershipAddr = ownership;
                  }
                  if (currOwnershipAddr == owner) {
                      if (tokenIdsIdx == index) {
                          return i;
                      }
                      tokenIdsIdx++;
                  }
              }
          }
          // Execution should never reach this point.
          assert(false);
          return 0;
      }


      function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
          return
              interfaceId == type(IERC721).interfaceId ||
              interfaceId == type(IERC721Metadata).interfaceId ||
              interfaceId == type(IERC721Enumerable).interfaceId ||
              super.supportsInterface(interfaceId);
      }


      function balanceOf(address owner) public view virtual override returns (uint256) {
          if (owner == address(0)) revert BalanceQueryForZeroAddress();
          return _balances[owner];
      }


      function ownerOf(uint256 tokenId) public view virtual override returns (address) {
          address owner = _owners[tokenId];
          if (owner == address(0)) revert OwnerQueryForNonexistentToken();
          return owner;
      }


      function name() public view virtual override returns (string memory) {
          return _name;
      }

      //
      function symbol() public view virtual override returns (string memory) {
          return _symbol;
      }


      function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();
        uint256 songId = songOfToken(tokenId);
        uint256 songSerial = serialOfToken(tokenId);
        string memory _tokenURI;
        // Shows different uri depending on serial number
        if (songSerial < 2) {
            _tokenURI = _songURIs[(songId * 3) - 2];
        } else if (songSerial < 11) {
            _tokenURI = _songURIs[(songId * 3) - 1];
        } else {
            _tokenURI = _songURIs[songId * 3];
          }
        // Set baseURI
        string memory base = _baseURI();
        // Concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        } else {
            return "";
        }

      }



    //
    //
    //URI Section
    //
    //
    //Define the baseURI
    string baseURI = "https://arweave.net/";

    //Returns baseURI internally
    function _baseURI() internal view virtual returns (string memory) {
        return baseURI;
    }

    //sets the baseURI
    function setBaseURI(string memory base) public onlyOwner virtual {
        baseURI = base;
    }

    //sets the songURIs when minting a new song
    function _setSongURI(uint256 songId, string memory songURI1, string memory songURI2, string memory songURI3)
    internal virtual {
        if (!_exists(songId)) revert URISetOfNonexistentSong();
        _songURIs[(songId * 3) - 2] = songURI1;
        _songURIs[(songId * 3) - 1] = songURI2;
        _songURIs[songId * 3] = songURI3;
    }

    //Changes the songURI for one edition of a song, when given the songId and songEdition
    function changeSongURI(uint256 songId, uint256 songEdition, string memory songURI) public onlyOwner virtual {
        if (!_exists(songId)) revert URISetOfNonexistentSong();

        if (songEdition == 1) {
                  _songURIs[(songId * 3) - 2] = songURI;
               } else if (songEdition == 2) {
                  _songURIs[(songId * 3) - 1] = songURI;
               } else if (songEdition == 3) {
                  _songURIs[songId * 3] = songURI;
               }
    }

    //
    //ERC721 Meat and Potatoes Section
    //

    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ownerOf(tokenId);
        if (to == owner) revert ApprovalToCurrentOwner();

        if (_msgSender() != owner && !isApprovedForAll(owner, _msgSender())) {
            revert ApprovalCallerNotOwnerNorApproved();
        }

        _approve(to, tokenId);
    }

    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        if (!_exists(tokenId)) revert ApprovalQueryForNonexistentToken();
        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    //
    //Transfer Section
    //
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
      if (!_isApprovedOrOwner(_msgSender(), tokenId)) revert TransferCallerNotOwnerNorApproved();
      _transfer(from, to, tokenId);
    }


    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }


    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
      if (!_isApprovedOrOwner(_msgSender(), tokenId)) revert TransferCallerNotOwnerNorApproved();
      _transfer(from, to, tokenId);
      if (!_checkOnERC721Received(from, to, tokenId, _data)) {
          revert TransferToNonERC721ReceiverImplementer();
      }
    }

    //
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }


    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        if (!_exists(tokenId)) revert QueryForNonexistentToken();
        address owner = ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    //
    //Minting Section!
    //

      function mintNewSong(string memory songURI1, string memory songURI2, string memory songURI3)
          public
          onlyOwner
      {
          // Updates the count of total tokenids and songids
          uint256 id = _tokenIds;
          id++;
          _tokenIds = id;
          uint256 songId = _songIds;
          songId++;
          _songIds = songId;

          _safeMint(msg.sender, id);
          _setSongURI(songId, songURI1, songURI2, songURI3);

          // Updates the count of how many of a particular song have been made
          uint256 songSerial = _songSerials[songId];
          songSerial ++;
          _songSerials[songId] = songSerial;
          //makes it easy to look up the song or serial of a tokenid
          _tokenIdInfo[id].song = uint128(songId);
          _tokenIdInfo[id].serial = uint128(songSerial);
      }


      function ownerMintsCopy(uint256 tokenId, address to)
          public
          onlyOwner
      {
          //requires the sender to have the tokenId in their wallet
          if (ownerOf(tokenId) != msg.sender) revert SenderNotOwner();
          //Gets the songId from the tokenId
          uint256 songId = songOfToken(tokenId);
          uint256 songSerial = _songSerials[songId];
          //requires the current amount of copies that song to be less than what's set
          if (songSerial >= 100) revert MaxCopiesReached();

          // Updates the count of total tokenids
          uint256 id = _tokenIds;
          id++;
          _tokenIds = id;

          _safeMint(to, id);

          //Updates the count of how many of a particular song have been made
          songSerial ++;
          _songSerials[songId] = songSerial;
          //makes it easy to look up the song or serial# of a tokenid
          _tokenIdInfo[id].song = uint128(songId);
          _tokenIdInfo[id].serial = uint128(songSerial);
      }


      function mintCopyTo(uint256 tokenId, address to)
          public
          payable
      {
          //requires eth
          if (msg.value < 0.05 ether) revert NotEnoughEther();
          //requires the sender to have the tokenId in their walle
          if (ownerOf(tokenId) != msg.sender) revert SenderNotOwner();
          //Gets the songId from the tokenId
          uint256 songId = songOfToken(tokenId);
          uint256 songSerial = _songSerials[songId];
          //requires the current amount of copies that song to be less than what's set
          if (songSerial >= 100) revert MaxCopiesReached();

          // Updates the count of total tokenids
          uint256 id = _tokenIds;
          id++;
          _tokenIds = id;

          _safeMint(to, id);

          //Updates the count of how many of a particular song have been made
          songSerial ++;
          _songSerials[songId] = songSerial;
          //makes it easy to look up the song or serial# of a tokenid
          _tokenIdInfo[id].song = uint128(songId);
          _tokenIdInfo[id].serial = uint128(songSerial);
      }


      function mintCopySong(uint256 tokenId)
          public
          payable
      {
          //requires eth
          if (msg.value < 0.05 ether) revert NotEnoughEther();
          //requires the sender to have the tokenId in their wallet
          if (ownerOf(tokenId) != msg.sender) revert SenderNotOwner();
          //Gets the songId from the tokenId
          uint256 songId = songOfToken(tokenId);
          uint256 songSerial = _songSerials[songId];
          //requires the current amount of copies that song to be less than what's set
          if (songSerial >= 100) revert MaxCopiesReached();

          // Updates the count of total tokenids
          uint256 id = _tokenIds;
          id++;
          _tokenIds = id;

          _safeMint(msg.sender, id);

          //Updates the count of how many of a particular song have been made
          songSerial ++;
          _songSerials[songId] = songSerial;
          //makes it easy to look up the song or serial# of a tokenid
          _tokenIdInfo[id].song = uint128(songId);
          _tokenIdInfo[id].serial = uint128(songSerial);
      }


      function _safeMint(address to, uint256 tokenId) internal virtual {
          _safeMint(to, tokenId, "");
      }


      function _safeMint(
          address to,
          uint256 tokenId,
          bytes memory _data
      ) internal virtual {
          _mint(to, tokenId);
          if (!_checkOnERC721Received(address(0), to, tokenId, _data)) {
              revert TransferToNonERC721ReceiverImplementer();
          }
      }


      function _mint(address to, uint256 tokenId) internal virtual {
          if (to == address(0)) revert MintToZeroAddress();
          if (_exists(tokenId)) revert TokenAlreadyMinted();

          _balances[to] += 1;
          _owners[tokenId] = to;

          emit Transfer(address(0), to, tokenId);
      }

    //
    //More ERC721 Functions Meat and Potatoes style Section
    //

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        if (ownerOf(tokenId) != from) revert TransferFromIncorrectOwner();
        if (to == address(0)) revert TransferToZeroAddress();

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

    }


    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }


    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        if (owner == operator) revert OwnerIsOperator();
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    //
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    //
    //Other Functions Section
    //

    //function returns how many different songs have been created
    function amountOfSongs() public view virtual returns (uint256) {
      return _songIds;
    }

    //function returns what song a certain tokenid is
    function songOfToken(uint256 tokenId) public view virtual returns (uint256) {
      return _tokenIdInfo[tokenId].song;
    }

    //function returns what serial number a certain tokenid is
    function serialOfToken(uint256 tokenId) public view virtual returns (uint256) {
      return _tokenIdInfo[tokenId].serial;
    }

    //function returns how many of a song are minted
    function songSupply(uint256 songId) public view virtual returns (uint256) {
      return _songSerials[songId];
    }


    //returns a songURI, when given the songId and songEdition
    function getSongURI(uint256 songId, uint256 songEdition) public view virtual returns (string memory) {
        if (!_exists(songId)) revert URIQueryForNonexistentToken();
        string memory _songURI;
        if (songEdition == 1) {
                  _songURI = _songURIs[(songId * 3) - 2];
               } else if (songEdition == 2) {
                  _songURI = _songURIs[(songId * 3) - 1];
               } else if (songEdition == 3) {
                  _songURI = _songURIs[songId * 3];
               }
        string memory base = _baseURI();
        return bytes(base).length > 0 ? string(abi.encodePacked(base, _songURI)) : "";
    }

    // Function to withdraw all Ether from this contract.
    function withdraw() public onlyOwner{
        uint amount = address(this).balance;
        // Payable address can receive Ether
        address payable owner;
        owner = payable(msg.sender);
        // send all Ether to owner
        (bool success, ) = owner.call{value: amount}("");
        require(success, "Failed to send Ether");
    }


}
