#!/usr/bin/env bun
/**
 * Convert an HTML file to PDF using Playwright (headless Chromium).
 *
 * Auto-detects slide decks (HTML with [data-slide] elements) and captures
 * each slide as a separate page. Regular HTML is printed as a continuous PDF.
 *
 * Usage:
 *   bun run html_to_pdf.ts <input.html> [output.pdf] [--slides|--page] [--width=N] [--height=N]
 */
import { chromium } from "playwright";
import { existsSync, mkdtempSync, statSync, unlinkSync, rmdirSync, writeFileSync, readdirSync } from "fs";
import { resolve, join } from "path";
import { tmpdir, homedir } from "os";

/** Find a working Chromium executable. Scans Playwright cache, then system Chrome. */
function findChromium(): string {
  const cacheDir = join(homedir(), "Library", "Caches", "ms-playwright");

  // Scan for any installed chromium version (not headless shell)
  if (existsSync(cacheDir)) {
    const entries = readdirSync(cacheDir)
      .filter((d) => d.startsWith("chromium-") && !d.includes("headless"))
      .sort()
      .reverse(); // highest version first

    for (const dir of entries) {
      const chromePath = join(
        cacheDir, dir,
        "chrome-mac-arm64",
        "Google Chrome for Testing.app",
        "Contents", "MacOS", "Google Chrome for Testing"
      );
      if (existsSync(chromePath)) return chromePath;
    }
  }

  // Fallback: system Chrome
  const systemChrome = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
  if (existsSync(systemChrome)) return systemChrome;

  throw new Error(
    "No Chromium found. Run `npx playwright install chromium` or install Google Chrome."
  );
}

interface Options {
  inputPath: string;
  outputPath: string;
  forceSlides: boolean;
  forcePage: boolean;
  vpWidth: number;
  vpHeight: number;
}

function parseArgs(): Options {
  const args = Bun.argv.slice(2);
  const flags = args.filter((a) => a.startsWith("--"));
  const positional = args.filter((a) => !a.startsWith("--"));

  if (positional.length < 1) {
    console.error(
      "Usage: bun run html_to_pdf.ts <input.html> [output.pdf] [--slides|--page] [--width=N] [--height=N]"
    );
    process.exit(1);
  }

  const inputPath = resolve(positional[0]);
  if (!existsSync(inputPath)) {
    console.error(`Error: input file not found: ${inputPath}`);
    process.exit(1);
  }

  const outputPath = positional[1]
    ? resolve(positional[1])
    : inputPath.replace(/\.html?$/i, ".pdf");

  const widthFlag = flags.find((f) => f.startsWith("--width="));
  const heightFlag = flags.find((f) => f.startsWith("--height="));

  return {
    inputPath,
    outputPath,
    forceSlides: flags.includes("--slides"),
    forcePage: flags.includes("--page"),
    vpWidth: widthFlag ? parseInt(widthFlag.split("=")[1]) : 1280,
    vpHeight: heightFlag ? parseInt(heightFlag.split("=")[1]) : 720,
  };
}

async function captureSlides(opts: Options): Promise<void> {
  const { inputPath, outputPath, vpWidth, vpHeight } = opts;

  // Find Chromium: prefer Playwright's installed version, fallback to system Chrome
  const execPath = findChromium();
  console.error(`Using Chromium: ${execPath}`);
  const browser = await chromium.launch({
    headless: true,
    executablePath: execPath,
  });
  const context = await browser.newContext({
    viewport: { width: vpWidth, height: vpHeight },
    deviceScaleFactor: 2, // retina-quality
  });

  const page = await context.newPage();
  await page.goto(`file://${inputPath}`, { waitUntil: "networkidle" });
  await page.waitForTimeout(500); // let fonts + CSS settle

  // Count slides
  const slideCount = await page.evaluate(() =>
    document.querySelectorAll("[data-slide]").length
  );

  const isSlideMode = opts.forceSlides || (!opts.forcePage && slideCount > 1);

  if (isSlideMode) {
    console.error(`Detected ${slideCount} slides. Capturing each at ${vpWidth}x${vpHeight}...`);

    const tmpDir = mkdtempSync(join(tmpdir(), "htmlpdf-"));
    const pngPaths: string[] = [];

    for (let i = 0; i < slideCount; i++) {
      await page.evaluate((idx: number) => {
        // Use showSlide if the deck defines it, otherwise toggle manually
        if (typeof (globalThis as any).showSlide === "function") {
          (globalThis as any).showSlide(idx);
        } else {
          const slides = document.querySelectorAll("[data-slide]");
          slides.forEach((s, j) => {
            (s as HTMLElement).classList.toggle("active", j === idx);
            (s as HTMLElement).style.display = j === idx ? "flex" : "none";
          });
        }
      }, i);

      await page.waitForTimeout(150); // transitions

      const pngPath = join(tmpDir, `slide-${String(i).padStart(3, "0")}.png`);
      await page.screenshot({ path: pngPath, fullPage: false });
      pngPaths.push(pngPath);
      console.error(`  Captured slide ${i + 1}/${slideCount}`);
    }

    // Assemble PNGs into PDF via a temporary HTML page
    const assemblyHtml = `<!DOCTYPE html>
<html><head><style>
  * { margin: 0; padding: 0; }
  body { background: #000; }
  .page { width: ${vpWidth}px; height: ${vpHeight}px; page-break-after: always; overflow: hidden; }
  .page:last-child { page-break-after: auto; }
  .page img { width: 100%; height: 100%; object-fit: contain; }
</style></head><body>
${pngPaths.map((p) => `<div class="page"><img src="file://${p}"></div>`).join("\n")}
</body></html>`;

    const assemblyPath = join(tmpDir, "assembly.html");
    writeFileSync(assemblyPath, assemblyHtml);

    const pdfPage = await context.newPage();
    await pdfPage.goto(`file://${assemblyPath}`, { waitUntil: "networkidle" });
    await pdfPage.waitForTimeout(300);

    await pdfPage.pdf({
      path: outputPath,
      width: `${vpWidth}px`,
      height: `${vpHeight}px`,
      printBackground: true,
      margin: { top: "0", right: "0", bottom: "0", left: "0" },
    });

    // Cleanup
    for (const p of pngPaths) {
      try { unlinkSync(p); } catch {}
    }
    try { unlinkSync(assemblyPath); } catch {}
    try { rmdirSync(tmpDir); } catch {}

    await pdfPage.close();
  } else {
    // Regular page mode
    console.error("Printing page to PDF...");
    await page.pdf({
      path: outputPath,
      format: "A4",
      printBackground: true,
      margin: { top: "1cm", right: "1cm", bottom: "1cm", left: "1cm" },
    });
  }

  await browser.close();

  const size = statSync(outputPath).size;
  const sizeKb = (size / 1024).toFixed(1);
  console.log(`Wrote ${outputPath} (${sizeKb} KB, ${isSlideMode ? slideCount + " slides" : "page mode"})`);
}

captureSlides(parseArgs()).catch((err) => {
  console.error(err);
  process.exit(1);
});
