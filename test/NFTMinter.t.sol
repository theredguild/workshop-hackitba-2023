// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";
import "../src/NFTMinter.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";

contract NFTMintersTest is Test /*, IERC721Receiver*/ {
    NFTMinter nftmin;
    address carlos = makeAddr("carlos");
    address karen = makeAddr("karen");
    bool exploitActive;
    uint8 exploitCount;
    uint8 exploitMaxCount;

    function setUp() public {
        // Carlos comienza con un balance de 1000 ETH
        vm.deal(carlos, 1000 ether);

        // A partir de ahora, todas las llamadas serán ejecutadas por carlos
        vm.startPrank(carlos);

        // Se instancia el contrato a testear
        nftmin = new NFTMinter(0.25 ether, 10);
    }

    receive() external payable {}

    function test_constructor() public {
        assertEq(0.25 ether, nftmin.PRICE_TO_PAY());
        assertFalse(address(nftmin.nft()) == address(0), "NFT not deployed");
    }

    function test_mintOne() public {
        uint256 balanceBefore = address(nftmin).balance;
        nftmin.mintOne{value: 1 ether}();
        uint256 balanceAfter = address(nftmin).balance;

        assertEq(nftmin.nft().getTotalMinted(), 1);
        // assertLt(balanceBefore, balanceAfter);
        assertEq(balanceBefore + nftmin.PRICE_TO_PAY(), balanceAfter);

        /** TODO:
         * - chequear si se mintea un NFT correctamente.
         * - chequear si efectivamente el contrato recibe el ether.
         */
    }

    function test_sweepFunds() public {
        uint256 balanceBefore = address(carlos).balance;

        vm.deal(karen, 1 ether);
        changePrank(karen);
        nftmin.mintOne{value: nftmin.PRICE_TO_PAY()}();

        changePrank(carlos);

        nftmin.sweepFunds();
        uint256 balanceAfter = address(carlos).balance;

        assertGt(balanceAfter, balanceBefore);

        /** TODO:
         * - testear que los fondos sólo van hacia carlos
         * - testear con karen como ejemplo con changePrank
         */
    }

    function test_mintMany() public {
        vm.deal(address(nftmin), 1000 ether);
        // vm.deal(carlos, 1000 ether);
        uint256 amount = 5;
        uint256 _value = amount * nftmin.PRICE_TO_PAY();
        nftmin.mintMany{value: _value}(amount);

        assertEq(
            nftmin.nft().balanceOf(carlos),
            amount,
            "No coinciden los montos"
        );

        _value = (nftmin.MINT_LIMIT() + 1) * nftmin.PRICE_TO_PAY();
        vm.expectRevert(AboveMintLimit.selector);
        nftmin.mintMany{value: _value}(11);

        /** TODO:
         * - la cantidad pedida tiene que coincidir con la real minteada
         * - no se deberían poder mintear más de 10 a la vez.
         */
    }

    function test_fuzz_minting(uint256 val, uint256 amount) public {
        val = bound(val, nftmin.PRICE_TO_PAY(), 10 ether);
        amount = bound(amount, 1, 10);
        vm.assume(val >= nftmin.PRICE_TO_PAY() * amount);

        uint256 accumulated;
        nftmin.mintMany{value: val}(amount);
        accumulated = nftmin.PRICE_TO_PAY() * amount;

        assertEq(accumulated, address(nftmin).balance);

        /** TODO:
         * Definir una variable fantasma:
         * comprobar que el valor que debería cobrarse es igual al valor
         * que recibe el contrato, aún cuando se le envía de más.
         */
    }

    function test_mintFree() public {
        vm.deal(carlos, 10 ether);
        uint256 amount = 5;
        uint256 _value = amount * nftmin.PRICE_TO_PAY();
        nftmin.mintMany{value: _value}(amount);

        vm.expectRevert(NotEnoughPoints.selector);
        nftmin.mintFree();

        nftmin.mintMany{value: _value}(amount);

        uint256 balanceBefore = nftmin.nft().balanceOf(carlos);
        nftmin.mintFree();
        uint256 balanceAfter = nftmin.nft().balanceOf(carlos);

        assertEq(balanceBefore + 1, balanceAfter);

        vm.expectRevert(AlreadyClaimed.selector);
        nftmin.mintFree();

        /** TODO:
         * - chequear que efectivamente de un NFT gratuito
         * - chequear que no pueda mintear si tiene pocos puntos
         * - chequear que no pueda mintear dos veces
         * tips:
         * - 2 expectReverts, 3 calls to mintFree, and 1 assert
         */
    }

    // function test_exploitReentrancy() public {
    //     // nota: ejecutando transacción como carlos
    //     vm.stopPrank();
    //     uint256 amount = nftmin.PRIZE_THRESHOLD();
    //     uint256 cost = nftmin.PRICE_TO_PAY() * amount;
    //     nftmin.mintMany{value: cost}(amount);

    //     // exploit context
    //     exploitActive = true;
    //     exploitMaxCount = 5;
    //     nftmin.mintFree();

    //     // chequear si funcionó
    //     assertEq(
    //         nftmin.nft().balanceOf(address(this)),
    //         amount + exploitMaxCount + 1
    //     );

    //     /** TODO:
    //      * - necesitamos un contrato para controlar el flujo de la ejecución
    //      * - necesitamos triggerear mintFree de manera satisfactoria
    //      * - una vez tomado el control, desarrollamos la lógica del exploit
    //      * - creamos su contexto antes de llamar, y su comportamiento en onERC721
    //      * - chequeamos que haya funcionado efectivamente
    //      * - solucionar el bug y esperar que falle
    //      */
    // }

    // function onERC721Received(
    //     address operator,
    //     address from,
    //     uint256 tokenId,
    //     bytes calldata data
    // ) external returns (bytes4) {
    //     if (exploitActive && exploitCount < exploitMaxCount) {
    //         exploitCount++;
    //         nftmin.mintFree();
    //     }
    //     return IERC721Receiver.onERC721Received.selector;
    // }

    // // working exploit
    // function onERC721Received(
    //     address operator,
    //     address from,
    //     uint256 tokenId,
    //     bytes calldata data
    // ) external returns (bytes4) {
    //     if (exploitReent && exploitCount < exploitMaxCount) {
    //         exploitCount++;
    //         NFTMinter(payable(address(operator))).mintFree();
    //         // analog to nftmin.mintFree();
    //     } else {
    //         exploitReent = false;
    //         delete exploitCount;
    //     }
    //     return IERC721Receiver.onERC721Received.selector;
    // }

    function test_mintFreeDeluxe() public {
        uint256 amount = 10;
        uint256 _value = amount * nftmin.PRICE_TO_PAY();
        nftmin.mintMany{value : _value}(amount);

        uint256 balanceBefore = nftmin.nft().balanceOf(carlos);
        nftmin.mintFreeDeluxe();
        uint256 balanceAfter = nftmin.nft().balanceOf(carlos);

        assertEq(balanceBefore + 1, balanceAfter);

        /** TODO:
         * (puntosUsuario / nftsMinteadosTotales * 100 > 20).
         * - mintear desde distintas cuentas
         * - chequear que entregue 1 nft
         * - chequear que no se pueda mintear dos veces
        */
    }

    function getsDeluxe(uint256 points) internal view returns (bool) {
        // Implementation by tincho
        points *= 100;
        points /= nftmin.nft().getTotalMinted();

        return points > 20;
    }

    function test_fuzz_mintDeluxe(uint256 val, uint256 amount) public {
        uint256 _value;
        vm.deal(carlos, 100 ether);
        vm.deal(karen, 100 ether);
        // acotar el fuzz con bound y assumes
        val = bound(val, nftmin.PRICE_TO_PAY(), 10 ether);
        amount = bound(amount, 1, 10);
        vm.assume(val >= nftmin.PRICE_TO_PAY() * amount);

        // minteamos con un primer usuario x veces
        changePrank(karen);
        _value = amount * nftmin.PRICE_TO_PAY();
        nftmin.mintMany{value : _value}(amount);
        nftmin.mintMany{value : _value}(amount);

        changePrank(carlos);
        nftmin.mintMany{value : _value}(amount);
        nftmin.mintMany{value : _value}(amount);

        // validamos que de igual el resultado de ambas funciones
        assertEq(getsDeluxe(amount), nftmin.mintFreeDeluxe());

        /** TODO:
         * - generar el contexto necesario para que se puedan comparar los
             resultados de las dos funciones
         * - mintear con dos usuarios, cantidades distintas, siendo que la
             cantidad de quién reclamará respete la condición para reclamar
         * - qué cosas podemos asumir que tengan sentido para esta prueba?
        */
    }

    // chisel demo
    // bool r
    // uint256 points = 10
    // uint256 total = 20
    // r = points/total * 100 > 20
    // r = points * 100 / total > 20
}
