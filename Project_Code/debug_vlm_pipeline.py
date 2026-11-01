"""
Full VLM Pipeline Debug Script
Traces: image load -> Gemini call -> raw response -> JSON parse -> final result
"""
import sys, os, json, re
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))

TEST_IMAGE = os.path.join(os.path.dirname(__file__), "test_foot.jpg")

# ─────────────────────────────────────────────────────────────────────────────
# STEP 1: Resolve which image file prediction_service.py will actually send
# ─────────────────────────────────────────────────────────────────────────────
print("\n" + "="*60)
print("STEP 1: Which image file will be sent to Gemini?")
print("="*60)

vlm_input = "cropped_foot.jpg" if os.path.exists("cropped_foot.jpg") else (
    "original_uploaded.jpg" if os.path.exists("original_uploaded.jpg") else (
        TEST_IMAGE if TEST_IMAGE else "uploaded_debug.jpg"
    )
)
print(f"  vlm_input resolved to: {vlm_input!r}")
print(f"  File exists: {os.path.exists(vlm_input)}")
if not os.path.exists(vlm_input):
    print("  [CRITICAL BUG] The resolved VLM input file does NOT exist on disk!")
    print("  prediction_service.py passes this path to analyze_foot_with_vlm()")
    print("  vlm_service._to_pil_image() will RAISE ValueError -> triggers fallback -> No Lesion Detected")
else:
    print("  File found OK.")

# ─────────────────────────────────────────────────────────────────────────────
# STEP 2: _to_pil_image — can it open the file?
# ─────────────────────────────────────────────────────────────────────────────
print("\n" + "="*60)
print("STEP 2: _to_pil_image() - can the file be opened?")
print("="*60)
try:
    from PIL import Image as PILImage
    pil = PILImage.open(vlm_input).convert("RGB")
    print(f"  PIL opened OK: size={pil.size}, mode={pil.mode}")
except Exception as e:
    print(f"  [CRITICAL BUG] PIL failed to open '{vlm_input}': {e}")
    print("  This would cause analyze_foot_with_vlm() fallback -> No Lesion Detected")

# ─────────────────────────────────────────────────────────────────────────────
# STEP 3: API key resolution
# ─────────────────────────────────────────────────────────────────────────────
print("\n" + "="*60)
print("STEP 3: API Key Resolution")
print("="*60)
try:
    import dotenv
    dotenv.load_dotenv(Path(__file__).resolve().parent / "backend" / ".env")
    dotenv.load_dotenv(Path(__file__).resolve().parent / ".env")
except ImportError:
    pass


env_key = os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
resolved_key = env_key
print(f"  GEMINI_API_KEY from env : {env_key[:20]+'...' if env_key else 'NOT SET'}")
print(f"  Key configured: {'YES' if resolved_key else 'NO'}")

# ─────────────────────────────────────────────────────────────────────────────
# STEP 4: Raw Gemini call — capture full response text
# ─────────────────────────────────────────────────────────────────────────────
print("\n" + "="*60)
print("STEP 4: Raw Gemini Vision API Call")
print("="*60)

raw_gemini_text = None
gemini_succeeded = False
gemini_exception = None

try:
    import google.generativeai as genai
    from backend.services.vlm_service import VLM_PROMPT
    genai.configure(api_key=resolved_key)
    model = genai.GenerativeModel("gemini-3.8-flash")
    print(f"  Model: gemini-3.8-flash")
    print(f"  Sending prompt + PIL image to Gemini...")
    print(f"  Image size: {pil.size}")

    response = model.generate_content([VLM_PROMPT, pil])
    raw_gemini_text = response.text.strip() if response and response.text else None

    print("\n  ================ GEMINI RAW RESPONSE ================")
    print(f"  {raw_gemini_text}")
    print("  =====================================================\n")

    if raw_gemini_text:
        gemini_succeeded = True
        print("  [OK] Gemini call SUCCEEDED and returned text.")
    else:
        print("  [BUG] Gemini returned empty response text.")
except Exception as exc:
    gemini_exception = exc
    print(f"  [ERROR] Gemini call FAILED: {exc}")
    print("  --> This would trigger OpenCV fallback -> No Lesion Detected")

# ─────────────────────────────────────────────────────────────────────────────
# STEP 5: JSON Parser — trace _parse_vlm_json_response
# ─────────────────────────────────────────────────────────────────────────────
print("\n" + "="*60)
print("STEP 5: JSON Parser (_parse_vlm_json_response)")
print("="*60)

if raw_gemini_text:
    try:
        clean_text = re.sub(r"```(?:json)?", "", raw_gemini_text, flags=re.IGNORECASE).strip("` \t\r\n")
        print(f"  Clean text after stripping markdown:\n  {clean_text[:300]}")

        match = re.search(r"\{.*\}", clean_text, re.DOTALL)
        if not match:
            print("  [BUG] regex failed to find JSON object in response!")
        else:
            parsed = json.loads(match.group(0))
            print(f"  Parsed JSON OK: {json.dumps(parsed, indent=2)}")

            pred_str  = str(parsed.get("prediction", "")).strip()
            pred_lower = pred_str.lower()
            print(f"\n  Gemini prediction string : '{pred_str}'")
            print(f"  Lowercase for matching   : '{pred_lower}'")

            if "severe" in pred_lower:
                matched_class = "Severe Foot Ulcer Detected"
            elif "ulcer" in pred_lower or "wound" in pred_lower or "breakdown" in pred_lower:
                matched_class = "Foot Ulcer Detected"
            else:
                matched_class = "No Lesion Detected"

            print(f"  Matched class            : '{matched_class}'")

            if matched_class == "No Lesion Detected" and ("ulcer" in pred_lower or "wound" in pred_lower or "severe" in pred_lower):
                print("  [BUG] Parser incorrectly mapped to No Lesion Detected despite ulcer keywords!")
            elif matched_class == "No Lesion Detected":
                print("  [INFO] Gemini genuinely said No Lesion — classification is correct for this image.")
            else:
                print(f"  [OK] Parser correctly preserved: {matched_class}")

    except json.JSONDecodeError as jexc:
        print(f"  [BUG] JSON parse FAILED with: {jexc}")
        print("  --> Parser returns None -> Gemini response is discarded -> fallback to No Lesion")
    except Exception as exc:
        print(f"  [BUG] Parser exception: {exc}")
else:
    print("  Skipped (Gemini call failed — no text to parse)")

# ─────────────────────────────────────────────────────────────────────────────
# STEP 6: Full analyze_foot_with_vlm() — print VLM Result vs check fallback
# ─────────────────────────────────────────────────────────────────────────────
print("\n" + "="*60)
print("STEP 6: Full analyze_foot_with_vlm() end-to-end result")
print("="*60)

from backend.services.vlm_service import analyze_foot_with_vlm

vlm_result = analyze_foot_with_vlm(vlm_input)
vlm_source = vlm_result.get("vlm_source", "unknown")

print(f"\n  VLM Result:")
print(f"  {json.dumps(vlm_result, indent=4)}")

print(f"\n  vlm_source = '{vlm_source}'")
if vlm_source == "gemini_vision_vlm":
    print("  --> Using Gemini Response  [Gemini path active]")
elif vlm_source in ("offline_opencv_fallback", "offline_default_fallback", "invalid_image_fallback"):
    print(f"  --> Using Offline Fallback [{vlm_source}]")
    print("  [ROOT CAUSE LIKELY HERE] Gemini was NOT used. Reason above explains why.")
else:
    print(f"  --> Unknown source: {vlm_source}")

# ─────────────────────────────────────────────────────────────────────────────
# STEP 7: Check prediction_service vlm_input logic
# ─────────────────────────────────────────────────────────────────────────────
print("\n" + "="*60)
print("STEP 7: prediction_service.py vlm_input resolution logic")
print("="*60)

files_checked = {
    "cropped_foot.jpg": os.path.exists("cropped_foot.jpg"),
    "original_uploaded.jpg": os.path.exists("original_uploaded.jpg"),
}
print(f"  cropped_foot.jpg exists     : {files_checked['cropped_foot.jpg']}")
print(f"  original_uploaded.jpg exists: {files_checked['original_uploaded.jpg']}")
print(f"  Resolved vlm_input          : '{vlm_input}'")
print()
if not files_checked["cropped_foot.jpg"] and not files_checked["original_uploaded.jpg"]:
    print("  [ROOT CAUSE CONFIRMED] Both intermediate files do not exist when the")
    print("  server is fresh (no prior foot prediction in this session).")
    print("  prediction_service falls back to image_url (the original Firebase/local path).")
    print("  IF image_url is a Firebase https:// URL, _to_pil_image() should fetch it.")
    print("  IF image_url is bytes (multipart upload), it's passed as-is and _to_pil_image handles bytes.")
    print()
    print("  BUT: if image_url is None (not passed through correctly), _to_pil_image")
    print("  raises ValueError -> exception -> except block -> default_response -> 'No Lesion Detected'")

print("\n" + "="*60)
print("STEP 8: Check forbidden_terms filter on 'reason' field")
print("="*60)
forbidden_terms = ["diabetes", "diabetic", "infection", "surgery", "hba1c", "glucose", "neuropathy"]
if raw_gemini_text:
    try:
        match = re.search(r"\{.*\}", re.sub(r"```(?:json)?", "", raw_gemini_text, flags=re.IGNORECASE).strip("` \t\r\n"), re.DOTALL)
        if match:
            parsed = json.loads(match.group(0))
            reason = str(parsed.get("reason", "")).strip()
            print(f"  Gemini reason: '{reason}'")
            hit = [t for t in forbidden_terms if t in reason.lower()]
            if hit:
                print(f"  [BUG] Forbidden terms found in reason: {hit}")
                print("  --> reason replaced by default_reason (this is OK, doesn't change prediction)")
            else:
                print("  No forbidden terms in reason. Reason is preserved as-is.")
    except Exception as e:
        print(f"  Could not check: {e}")
else:
    print("  Skipped (no Gemini text available)")

print("\n" + "="*60)
print("SUMMARY")
print("="*60)
print(f"  Gemini call succeeded  : {gemini_succeeded}")
print(f"  vlm_source             : {vlm_result.get('vlm_source', 'unknown')}")
print(f"  Final prediction       : {vlm_result.get('prediction')}")
print(f"  confidence             : {vlm_result.get('confidence')}")
if gemini_exception:
    print(f"  Gemini exception       : {gemini_exception}")
