import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const wallet1 = accounts.get("wallet_1")!;

describe("achievements contract", () => {
  it("allows owner to add an achievement", () => {
    const addAchievementCall = simnet.callPublicFn(
      "gaming",
      "add-achievement",
      [
        Cl.uint(1),
        Cl.stringAscii("First Win"),
        Cl.stringAscii("Win your first game"),
        Cl.uint(100)
      ],
      deployer
    );
    expect(addAchievementCall.result).toBeOk(Cl.bool(true));
  });

  it("allows user to claim achievement", () => {
    // First add the achievement
    simnet.callPublicFn(
      "gaming",
      "add-achievement",
      [
        Cl.uint(1),
        Cl.stringAscii("First Win"),
        Cl.stringAscii("Win your first game"),
        Cl.uint(100)
      ],
      deployer
    );

    // Then claim it
    const claimCall = simnet.callPublicFn(
      "gaming",
      "claim-achievement",
      [Cl.uint(1)],
      wallet1
    );
    expect(claimCall.result).toBeOk(Cl.bool(true));

    // Verify the claim
    const hasAchievementCall = simnet.callReadOnlyFn(
      "gaming",
      "has-achievement",
      [Cl.principal(wallet1), Cl.uint(1)],
      wallet1
    );
    // Changed to match the Optional return type
    expect(hasAchievementCall.result).toBeSome(Cl.tuple({
      claimed: Cl.bool(true),
      'claimed-at': Cl.uint(4)
    }));
  });

  it("retrieves achievement data correctly", () => {
    simnet.callPublicFn(
      "gaming",
      "add-achievement",
      [
        Cl.uint(1),
        Cl.stringAscii("First Win"),
        Cl.stringAscii("Win your first game"),
        Cl.uint(100)
      ],
      deployer
    );

    const getAchievementCall = simnet.callReadOnlyFn(
      "gaming",
      "get-achievement",
      [Cl.uint(1)],
      wallet1
    );
    
    // Changed to match the Optional return type
    expect(getAchievementCall.result).toBeSome(Cl.tuple({
      name: Cl.stringAscii("First Win"),
      description: Cl.stringAscii("Win your first game"),
      points: Cl.uint(100)
    }));
  });
});
