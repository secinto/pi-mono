import { describe, expect, it } from "vitest";
import { SessionManager } from "../../src/core/session-manager.ts";

/**
 * The compaction trigger reason is known inside _checkCompaction (threshold vs
 * overflow-recovery vs manual) and is already delivered to extensions on the
 * session_before_compact / session_compact events — but it was never written to
 * the session file, so a post-hoc read of the transcript could not tell why a
 * compaction happened.
 *
 * That gap made a real incident unexplainable: a session compacted at
 * 51211/196608 tokens (26%), which no threshold explains. It was in fact an
 * overflow-recovery compaction from a length-stopped response
 * (isRecoverableLength fires at ANY context size), but the transcript recorded
 * only {tokensBefore, firstKeptEntryId, fromHook} — leaving the cause
 * indeterminable days later.
 */
describe("appendCompaction: trigger provenance", () => {
	function manager(): SessionManager {
		return SessionManager.inMemory();
	}

	it("persists the trigger reason on the compaction entry", () => {
		const sm = manager();
		sm.appendCompaction("summary", "entry-1", 51211, undefined, false, undefined, "overflow", true);
		const entry = sm.getEntries().find((e) => e.type === "compaction");
		expect(entry).toBeDefined();
		expect(entry).toMatchObject({ reason: "overflow", willRetry: true, tokensBefore: 51211 });
	});

	it("persists a threshold compaction as such", () => {
		const sm = manager();
		sm.appendCompaction("s", "e", 127795, undefined, false, undefined, "threshold", false);
		const entry = sm.getEntries().find((e) => e.type === "compaction");
		expect(entry).toMatchObject({ reason: "threshold", willRetry: false });
	});

	it("omits the fields when the caller does not supply them (older sessions stay valid)", () => {
		const sm = manager();
		sm.appendCompaction("s", "e", 100);
		const entry = sm.getEntries().find((e) => e.type === "compaction");
		expect(entry).toBeDefined();
		expect(entry && "reason" in entry).toBe(false);
		expect(entry && "willRetry" in entry).toBe(false);
	});
});
