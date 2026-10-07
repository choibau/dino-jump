# 크롬 공룡점프 — 배포 가이드

빌드 과정이 없는 정적 사이트입니다. (`index.html`, `config.js`)

## 1. Supabase
1. https://supabase.com → New project 생성
2. SQL Editor → `supabase/schema.sql` 전체 붙여넣고 Run
3. Project Settings → API 에서 **Project URL**, **anon public key** 복사
4. `config.js`에 붙여넣기

## 2. GitHub
```bash
git init
git add .
git commit -m "크롬 공룡점프"
git branch -M main
git remote add origin https://github.com/<아이디>/dino-jump.git
git push -u origin main
```

## 3. Vercel
1. https://vercel.com → Add New → Project → GitHub 저장소 `dino-jump` Import
2. Framework Preset: `Other` / Build Command 비움 / Output 비움 → Deploy
3. 발급된 `https://dino-jump-xxxx.vercel.app` 주소를 공유하면 누구나 플레이

`config.js`가 비어 있으면 브라우저 로컬 저장 모드로 동작하므로, 반드시 채운 뒤 배포하세요.
