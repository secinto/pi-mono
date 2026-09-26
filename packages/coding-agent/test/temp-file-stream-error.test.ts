import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { executeBashWithOperations } from "../src/core/bash-executor.ts";
import type { BashOperations } from "../src/core/tools/bash.ts";
import { OutputAccumulator } from "../src/core/tools/output-accumulator.ts";
import { DEFAULT_MAX_BYTES } from "../src/core/tools/truncate.ts";

// A full disk (ENOSPC) or a missing temp dir makes the temp-file WriteStream
// emit 'error'. With no listener that event is thrown as an uncaught exception
// and kills the whole process mid-command. The temp file is only a copy of
// the full output for later reading, so losing it must degrade the tool, not
// end the run. Pointing TMPDIR at a directory that does not exist reproduces
// the same asynchronous stream error without filling a disk.
const tick = () => new Promise((resolve) => setTimeout(resolve, 20));

describe("temp-file stream errors do not kill the process", () => {
	const savedTmp = process.env.TMPDIR;
	beforeEach(() => {
		process.env.TMPDIR = "/nonexistent-pi-test-dir/sub";
	});
	afterEach(() => {
		process.env.TMPDIR = savedTmp;
	});

	it("executeBashWithOperations returns its output when the temp file cannot be written", async () => {
		const big = Buffer.from("x".repeat(DEFAULT_MAX_BYTES + 1024));
		const operations: BashOperations = {
			exec: async (_command, _cwd, { onData }) => {
				onData(big);
				await tick(); // let the stream report its error mid-command
				onData(Buffer.from("tail\n"));
				return { exitCode: 0 };
			},
		};

		const result = await executeBashWithOperations("cat big", "/", operations);
		await tick();

		expect(result.exitCode).toBe(0);
		expect(result.output).toContain("tail");
		expect(result.fullOutputPath).toBeUndefined();
	});

	it("OutputAccumulator keeps accumulating when the temp file cannot be written", async () => {
		const acc = new OutputAccumulator({ maxBytes: 1024, maxLines: 10_000 });
		acc.append(Buffer.from(`${"y".repeat(4096)}\n`));
		await tick();
		acc.append(Buffer.from("more\n"));
		await tick();
		acc.finish();
		await expect(acc.closeTempFile()).resolves.toBeUndefined();
		const snapshot = acc.snapshot();
		expect(snapshot.content).toContain("more");
		expect(snapshot.fullOutputPath).toBeUndefined();
	});
});
