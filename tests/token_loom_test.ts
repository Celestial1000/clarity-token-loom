import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Can mint a new chapter",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('token-loom', 'mint-chapter', [
        types.ascii("Chapter 1"),
        types.utf8("Once upon a time...")
      ], deployer.address)
    ]);
    
    block.receipts[0].result.expectOk().expectUint(1);
    
    let chapter = chain.callReadOnlyFn(
      'token-loom',
      'get-chapter',
      [types.uint(1)],
      deployer.address
    );
    
    assertEquals(chapter.result.expectSome().data.title, "Chapter 1");
  },
});

Clarinet.test({
  name: "Can link chapters",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('token-loom', 'mint-chapter', [
        types.ascii("Chapter 1"),
        types.utf8("First chapter")
      ], deployer.address),
      Tx.contractCall('token-loom', 'mint-chapter', [
        types.ascii("Chapter 2"),
        types.utf8("Second chapter")
      ], deployer.address),
      Tx.contractCall('token-loom', 'link-chapters', [
        types.uint(1),
        types.uint(2)
      ], deployer.address)
    ]);
    
    block.receipts.slice(0, 2).forEach(receipt => {
      receipt.result.expectOk();
    });
    
    block.receipts[2].result.expectOk().expectBool(true);
  },
});

Clarinet.test({
  name: "Can create story arc",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('token-loom', 'mint-chapter', [
        types.ascii("Chapter 1"),
        types.utf8("First chapter")
      ], deployer.address),
      Tx.contractCall('token-loom', 'create-story-arc', [
        types.ascii("My Story"),
        types.uint(1)
      ], deployer.address)
    ]);
    
    block.receipts.forEach(receipt => {
      receipt.result.expectOk();
    });
    
    let arc = chain.callReadOnlyFn(
      'token-loom',
      'get-story-arc',
      [types.uint(2)],
      deployer.address
    );
    
    assertEquals(arc.result.expectSome().data.title, "My Story");
  },
});