#!/usr/bin/env bash
# PDF 압축 스크립트 — Ghostscript /ebook 150dpi
# 사용법: bash compress_pdfs.sh
# 요구사항: Ghostscript 설치 필요 (winget install ArtifexSoftware.GhostScript)

set -e

SAMPLES="C:/Users/are48/OneDrive/Desktop/포트폴리오/samples"
BACKUP="C:/Users/are48/OneDrive/Desktop/포트폴리오/samples_original"

# --- Ghostscript 실행 파일 자동 탐색 ---
GS=""
for candidate in \
    gswin64c gswin32c gs \
    "/c/Program Files/gs/gs10.*/bin/gswin64c.exe" \
    "/c/Program Files/gs/gs9.*/bin/gswin64c.exe"; do
    expanded=$(ls $candidate 2>/dev/null | tail -1)
    if [ -n "$expanded" ] && command -v "$expanded" &>/dev/null 2>&1; then
        GS="$expanded"; break
    fi
    if command -v "$candidate" &>/dev/null 2>&1; then
        GS="$candidate"; break
    fi
done

if [ -z "$GS" ]; then
    echo "[ERROR] Ghostscript를 찾을 수 없습니다."
    echo "  설치: winget install --id ArtifexSoftware.GhostScript -e"
    exit 1
fi
echo "[INFO] Ghostscript: $GS"
echo

# --- 백업 디렉토리 생성 ---
mkdir -p "$BACKUP"

# --- 압축 실행 ---
compress_pdf() {
    local input="$1"
    local filename=$(basename "$input")
    local output="$SAMPLES/${filename}"
    local backup="$BACKUP/${filename}"

    # 원본 크기
    local orig_size=$(du -k "$input" | cut -f1)

    # 이미 백업이 없으면 백업
    if [ ! -f "$backup" ]; then
        cp "$input" "$backup"
        echo "  [백업] $filename → samples_original/"
    else
        echo "  [백업 존재] $filename — 덮어쓰기 생략"
    fi

    # 임시 파일로 압축
    local tmp="${output}.tmp.pdf"
    "$GS" \
        -dBATCH -dNOPAUSE -dQUIET \
        -sDEVICE=pdfwrite \
        -dCompatibilityLevel=1.5 \
        -dPDFSETTINGS=/ebook \
        -dColorImageResolution=150 \
        -dGrayImageResolution=150 \
        -dMonoImageResolution=150 \
        -dColorImageDownsampleType=/Bicubic \
        -dGrayImageDownsampleType=/Bicubic \
        -dDownsampleColorImages=true \
        -dDownsampleGrayImages=true \
        -sOutputFile="$tmp" \
        "$backup" 2>/dev/null

    # 압축 결과 검증 — 원본보다 커지면 원본 유지
    local new_size=$(du -k "$tmp" | cut -f1)
    local ratio=0
    if [ "$orig_size" -gt 0 ]; then
        ratio=$(( (orig_size - new_size) * 100 / orig_size ))
    fi

    if [ "$new_size" -ge "$orig_size" ]; then
        rm -f "$tmp"
        echo "  [SKIP] $filename — 압축 효과 없음 (원본 유지)"
    else
        mv "$tmp" "$output"
        printf "  [OK]   %-36s  %5dKB → %5dKB  (-%d%%)\n" \
            "$filename" "$orig_size" "$new_size" "$ratio"
    fi
}

echo "=== PDF 압축 시작 ==="
echo "설정: /ebook (150dpi, Bicubic downsample)"
echo

for pdf in "$SAMPLES"/*.pdf; do
    compress_pdf "$pdf"
done

echo
echo "=== 완료 ==="
echo
echo "--- 최종 용량 비교 ---"
echo "[원본 samples_original/]"
du -sh "$BACKUP"/*.pdf 2>/dev/null | sort -k1 -h

echo
echo "[압축 후 samples/]"
du -sh "$SAMPLES"/*.pdf 2>/dev/null | sort -k1 -h

echo
echo "--- 품질 확인 방법 ---"
echo "1. 브라우저에서 samples/*.pdf 파일을 열어 텍스트·이미지 선명도 확인"
echo "2. 이미지가 흐리면 samples_original/ 에서 해당 파일만 복원:"
echo "   cp samples_original/<파일명>.pdf samples/<파일명>.pdf"
echo "3. 텍스트만 있는 PDF(c-basic-lesson7.pdf 등)는 압축 효과 미미"
