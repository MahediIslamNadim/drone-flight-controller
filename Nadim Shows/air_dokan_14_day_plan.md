
# 🚀 Air Dokan - Proper Implementation Plan
## Using ChatGPT Plus + Codex (No API Key Needed)

---

## 📅 Timeline: 14 Days to Launch

### Phase 1: Foundation (Day 1-3)
### Phase 2: Core Features (Day 4-7)
### Phase 3: AI Integration (Day 8-10)
### Phase 4: Polish & Launch (Day 11-14)

---

## 🛠️ Tools You Need

| Tool | Purpose | Cost |
|------|---------|------|
| **ChatGPT Plus** | Codex for coding + GPT-4o Vision | $20/month (আপনার আছে) |
| **Supabase** | Database + Storage + Auth | Free tier |
| **Vercel** | Website hosting | Free tier |
| **GitHub** | Code storage | Free |
| **Mobile Phone** | Testing + Abbu's admin access | আপনার আছে |

---

## 📋 Daily Plan

---

### 🟢 DAY 1: Project Setup & Database

#### Morning (2 hours)
**Step 1: Create Supabase Project**
```
১. Go to supabase.com
২. Sign up with Gmail
৩. Click "New Project"
৪. Name: air-dokan
৫. Password: [strong password লিখে রাখুন]
৬. Region: Singapore (closest to Bangladesh)
৭. Wait 2 minutes for project creation
```

**Step 2: Get Supabase Credentials**
```
১. Project dashboard এ যান
২. Settings → API
৩. Copy these:
   - Project URL (NEXT_PUBLIC_SUPABASE_URL)
   - anon public key (NEXT_PUBLIC_SUPABASE_ANON_KEY)
   - service_role key (SUPABASE_SERVICE_ROLE_KEY)
৪. Notepad এ সেভ করুন
```

#### Afternoon (2 hours)
**Step 3: Create Database Tables**
```sql
-- Go to Supabase Dashboard → SQL Editor → New Query
-- Paste this and Run

-- Brands table
CREATE TABLE brands (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    logo_url TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Categories table
CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Shoes table
CREATE TABLE shoes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    brand_id UUID REFERENCES brands(id),
    category_id UUID REFERENCES categories(id),
    name_bn VARCHAR(200) NOT NULL,
    name_en VARCHAR(200) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    image_urls TEXT[] DEFAULT '{}',
    colors VARCHAR(50)[],
    materials VARCHAR(100)[],
    style_type VARCHAR(50),
    gender VARCHAR(20),
    stock_status VARCHAR(20) DEFAULT 'in_stock',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Shoe sizes table
CREATE TABLE shoe_sizes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shoe_id UUID REFERENCES shoes(id) ON DELETE CASCADE,
    size VARCHAR(10) NOT NULL,
    stock_quantity INTEGER DEFAULT 0,
    is_available BOOLEAN DEFAULT true,
    UNIQUE(shoe_id, size)
);

-- Insert default brands
INSERT INTO brands (name, slug) VALUES 
('Bata', 'bata'),
('Apex', 'apex'),
('Nike', 'nike'),
('Adidas', 'adidas'),
('Lotto', 'lotto'),
('Power', 'power'),
('Sprint', 'sprint'),
('Unknown', 'unknown');

-- Insert default categories
INSERT INTO categories (name, slug) VALUES 
('Formal', 'formal'),
('Casual', 'casual'),
('Sports', 'sports'),
('Sandal', 'sandal'),
('Boot', 'boot'),
('Slipper', 'slipper');
```

**Step 4: Enable Storage**
```
১. Supabase Dashboard → Storage
২. Click "New Bucket"
৩. Name: shoe-images
৪. Public bucket: ✅ ON
৫. Click "Create"
```

#### Evening (1 hour)
**Step 5: Test Connection**
```
১. Supabase Dashboard → Table Editor
২. Check if brands and categories show data
৩. If yes, database ready!
```

---

### 🟢 DAY 2: Next.js Project Setup

#### Morning (2 hours)
**Step 1: Open Codex in ChatGPT Plus**
```
১. Open chat.openai.com
২. Start new chat
৩. Select "Code" or type "Open Codex"
৪. You will see a coding interface with terminal
```

**Step 2: Create Next.js Project**
```bash
# In Codex terminal, type:
npx create-next-app@latest air-dokan --typescript --tailwind --eslint --app --src-dir=false --import-alias="@/*"

# Wait for completion
# Then:
cd air-dokan
```

**Step 3: Install Dependencies**
```bash
# In Codex terminal:
npm install @supabase/supabase-js @supabase/ssr
npm install lucide-react
npm install next-pwa
```

#### Afternoon (2 hours)
**Step 4: Setup Environment Variables**
```bash
# In Codex terminal:
touch .env.local
```

```env
# Paste this in .env.local (your Supabase credentials):
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-key
NEXT_PUBLIC_APP_NAME=Air Dokan
NEXT_PUBLIC_APP_URL=https://localhost:3000
```

**Step 5: Create Supabase Client**
```bash
# In Codex terminal:
mkdir -p lib/supabase
```

```typescript
// lib/supabase/client.ts
import { createBrowserClient } from '@supabase/ssr'

export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  )
}
```

```typescript
// lib/supabase/server.ts
import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'

export function createClient() {
  const cookieStore = cookies()

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        get(name: string) {
          return cookieStore.get(name)?.value
        },
      },
    }
  )
}
```

#### Evening (1 hour)
**Step 6: Test Local Server**
```bash
# In Codex terminal:
npm run dev

# Should show: Ready on http://localhost:3000
```

---

### 🟢 DAY 3: Frontend Pages

#### Morning (2 hours)
**Step 1: Create Homepage**
```
Codex-এ বলুন:
"Create a beautiful homepage for Air Dokan shoe store with:
- Hero section with store name
- Category grid (Formal, Casual, Sports, Sandal)
- Featured shoes section
- Store info (address: Katakhal Bazar, Mithamin, Kishoreganj)
- WhatsApp contact button
Use Tailwind CSS, make it mobile-responsive"
```

**Step 2: Create Shoe Listing Page**
```
Codex-এ বলুন:
"Create /shoes page that:
- Fetches shoes from Supabase
- Shows grid of shoe cards with image, name, price
- Has filter sidebar (brand, category, price range, size)
- Has sort dropdown (price low-high, new arrivals)
- Mobile responsive with filter drawer"
```

#### Afternoon (2 hours)
**Step 3: Create Shoe Detail Page**
```
Codex-এ বলুন:
"Create /shoes/[id] page that:
- Shows large image gallery
- Shows name (Bangla + English), price
- Shows available sizes with stock status
- Shows color, material, style info
- Has 'Call to Order' WhatsApp button
- Has 'Book Now' button (simple form)
- Shows related shoes"
```

**Step 4: Create Layout & Navigation**
```
Codex-এ বলুন:
"Create root layout with:
- Top navigation with logo, search, menu
- Mobile hamburger menu
- Footer with store info
- Make it clean and professional"
```

#### Evening (1 hour)
**Step 5: Test Pages**
```
১. localhost:3000 দেখুন
২. localhost:3000/shoes দেখুন
৩. মোবাইলে দেখুন (browser dev tools → mobile view)
```

---

### 🟢 DAY 4: Admin Panel Setup

#### Morning (2 hours)
**Step 1: Create Admin Layout**
```
Codex-এ বলুন:
"Create admin panel at /admin with:
- Simple login page (password only, no complex auth)
- Dashboard layout with sidebar navigation
- Mobile responsive (Abbu will use mobile)
- Bangla labels for Abbu: 'নতুন জুতা', 'স্টক', 'বিক্রি'"
```

**Step 2: Create Admin Dashboard**
```
Codex-এ বলুন:
"Create /admin/dashboard with:
- Total shoes count
- Today's sales (manual entry)
- Low stock alerts
- Quick links to add shoe, update stock
- Simple charts if possible"
```

#### Afternoon (2 hours)
**Step 3: Create "Add Shoe" Page**
```
Codex-এ বলুন:
"Create /admin/shoes/add with this EXACT flow:

1. Photo upload section:
   - Drag & drop or click to upload
   - Preview uploaded photos
   - Show upload progress

2. AI Analysis section (manual for now):
   - Input fields for all shoe info
   - Brand dropdown (from database)
   - Category dropdown
   - Name (Bangla + English)
   - Price input
   - Colors multi-select
   - Materials multi-select
   - Style, Gender dropdowns

3. Size & Stock section:
   - Grid of sizes (36-44)
   - Each size has checkbox + quantity input
   - Visual stock indicator

4. Save button

Make it VERY simple, large buttons, mobile-first design"
```

#### Evening (1 hour)
**Step 4: Test Admin Panel**
```
১. localhost:3000/admin দেখুন
২. Login test করুন
৩. Add shoe form test করুন
```

---

### 🟢 DAY 5: Stock Management

#### Morning (2 hours)
**Step 1: Create Stock List Page**
```
Codex-এ বলুন:
"Create /admin/stock page:
- List all shoes with current stock
- Search/filter by name
- Quick edit stock per size
- Color coding: Green (good), Yellow (low <3), Red (out of stock)
- Mobile responsive table (cards on mobile)"
```

**Step 2: Create Quick Sale Page**
```
Codex-এ বলুন:
"Create /admin/sales/add page for Abbu:
- Search shoe by name (with photo)
- Select size
- Enter quantity sold (default 1)
- Auto deduct from stock
- Show today's sales summary
- VERY simple, 3 taps max"
```

#### Afternoon (2 hours)
**Step 3: Create Stock Update API**
```
Codex-এ বলুন:
"Create API routes:
- POST /api/admin/shoes - Create new shoe
- PUT /api/admin/shoes/[id] - Update shoe
- POST /api/admin/stock/update - Update stock quantity
- GET /api/admin/stock/low - Get low stock items

Use Supabase server client, handle errors properly"
```

#### Evening (1 hour)
**Step 4: Connect Frontend to API**
```
Codex-এ বলুন:
"Connect the admin forms to these APIs:
- Add shoe form → POST /api/admin/shoes
- Stock update → POST /api/admin/stock/update
- Show success/error messages"
```

---

### 🟢 DAY 6: WhatsApp Integration

#### Morning (1 hour)
**Step 1: Add WhatsApp Buttons**
```
Codex-এ বলুন:
"Add WhatsApp integration:
- On shoe detail page: 'WhatsApp এ অর্ডার করুন' button
- Pre-filled message: 'Air Dokan থেকে [Shoe Name] [Size] সাইজ চাই'
- Link: https://wa.me/8801XXXXXXXXX?text=encoded_message
- On admin: Show customer messages (if possible)"
```

**Step 2: Add Store Info**
```
Codex-এ বলুন:
"Add store information everywhere:
- Footer: Address, Phone, Hours
- Contact page with map placeholder
- WhatsApp floating button on all pages"
```

#### Afternoon (1 hour)
**Step 3: Test Complete Flow**
```
১. Customer view: Homepage → Shoe → WhatsApp order
২. Admin view: Login → Add shoe → Update stock → Record sale
৩. Check database if everything saves correctly
```

#### Evening (1 hour)
**Step 4: Bug Fixes**
```
Codex-এ এরর দেখিয়ে বলুন:
"Fix this error: [paste error message]"
```

---

### 🟢 DAY 7: AI Photo Analysis (GPT-4o Vision)

#### Morning (2 hours)
**Step 1: Create AI Analysis API**
```
Codex-এ বলুন:
"Create /api/admin/ai/analyze route:
- Accepts image upload
- Uses GPT-4o Vision to analyze shoe
- Returns JSON: brand, style, gender, colors, material, suggested_price, name_bn, name_en
- Use OpenAI client with API key from env"
```

**IMPORTANT: You need OpenAI API key for this**
```
Options:
A. Use your Plus account's limited API access (if available)
B. Buy $5 credit at platform.openai.com
C. Skip AI for now, add later
```

#### Afternoon (2 hours)
**Step 2: Integrate AI in Admin**
```
Codex-এ বলুন:
"Update /admin/shoes/add:
- After photo upload, show 'AI Analyze' button
- Click → Call /api/admin/ai/analyze
- Show loading state
- Auto-fill form fields with AI response
- Highlight AI-filled fields with color
- Allow Abbu to edit before saving"
```

#### Evening (1 hour)
**Step 3: Test AI Flow**
```
১. Upload a shoe photo in admin
২. Click AI Analyze
৩. Check if fields auto-fill correctly
৪. Edit if needed, save
```

---

### 🟢 DAY 8: Photo Enhancement

#### Morning (2 hours)
**Step 1: Setup Image Processing**
```
Options for background removal:
A. Remove.bg API (free 50 images, then $0.02/image)
B. @imgly/background-removal (free, runs in browser)
C. Skip enhancement, use original photos
```

```
Codex-এ বলুন:
"Add photo enhancement to /admin/shoes/add:
- After upload, show 'Enhance Photo' button
- Use @imgly/background-removal to remove background
- Add white background with shadow
- Show before/after comparison
- Let Abbu choose which to use"
```

#### Afternoon (2 hours)
**Step 2: Multiple Photo Upload**
```
Codex-এ বলুন:
"Allow multiple photo upload (max 3):
- Front view (required)
- Side view (optional)
- Top/Detail view (optional)
- Show all in gallery on shoe detail page"
```

#### Evening (1 hour)
**Step 3: Optimize Images**
```
Codex-এ বলুন:
"Add image optimization:
- Compress before upload
- Resize to max 1200px width
- Convert to WebP format
- Show upload progress"
```

---

### 🟢 DAY 9: PWA & Mobile Optimization

#### Morning (2 hours)
**Step 1: Convert to PWA**
```
Codex-এ বলুন:
"Convert Next.js app to PWA:
- Install next-pwa
- Create manifest.json with store info
- Add icons (use simple emoji or text-based icon)
- Configure service worker
- Make it installable on mobile"
```

**Step 2: Add to Home Screen**
```
১. Test on mobile browser
২. Check 'Add to Home Screen' prompt
৩. Verify it opens like native app
```

#### Afternoon (2 hours)
**Step 3: Mobile-First Admin**
```
Codex-এ বলুন:
"Optimize admin panel for Abbu's mobile:
- Large buttons (min 48px touch target)
- Large text (16px minimum)
- Simple forms with less scrolling
- Bottom navigation (easy thumb reach)
- Offline support for stock viewing"
```

#### Evening (1 hour)
**Step 4: Test on Real Mobile**
```
১. ngrok ব্যবহার করে লাইভ URL তৈরি করুন
২. মোবাইলে ওপেন করুন
৩. প্রতিটা ফিচার টেস্ট করুন
```

---

### 🟢 DAY 10: Search & Filter

#### Morning (2 hours)
**Step 1: Add Search**
```
Codex-এ বলুন:
"Add search functionality:
- Search bar in header
- Search by name (Bangla + English)
- Search by brand
- Show results in real-time (debounced)
- Highlight matching text"
```

**Step 2: Advanced Filter**
```
Codex-এ বলুন:
"Add filter drawer for mobile:
- Price range slider
- Brand checkboxes
- Size checkboxes
- Color swatches
- Style buttons
- Apply/Clear buttons"
```

#### Afternoon (2 hours)
**Step 3: Sort Options**
```
Codex-এ বলুন:
"Add sort dropdown:
- Price: Low to High
- Price: High to Low
- Newest First
- Popular (most viewed)"
```

#### Evening (1 hour)
**Step 4: SEO Optimization**
```
Codex-এ বলুন:
"Add SEO:
- Meta tags for each page
- Open Graph tags for social sharing
- Structured data for products
- Sitemap generation
- robots.txt"
```

---

### 🟢 DAY 11: Testing & Bug Fixes

#### Morning (3 hours)
**Complete Testing Checklist:**
```
□ Homepage loads fast (< 3 seconds)
□ Shoe listing shows correctly
□ Filter works on mobile
□ Search finds shoes
□ Shoe detail shows all info
□ WhatsApp button works
□ Admin login works
□ Add shoe saves to database
□ Stock update reflects immediately
□ Photo upload works
□ AI analysis returns correct data (if using)
□ PWA installs on mobile
□ Works offline (basic pages)
```

#### Afternoon (2 hours)
**Bug Fixing**
```
Codex-এ প্রতিটা এরর দেখান:
"This error occurred: [screenshot/paste]
Fix it please"
```

#### Evening (1 hour)
**Performance Check**
```
Codex-এ বলুন:
"Optimize performance:
- Add image lazy loading
- Add route prefetching
- Minimize bundle size
- Check Lighthouse score"
```

---

### 🟢 DAY 12: Content & Data Entry

#### Morning (2 hours)
**Add Real Shoes**
```
১. বাড়িতে থাকা জুতার ছবি তুলুন
২. Admin panel দিয়ে যোগ করুন
৩. AI analysis দিয়ে auto-fill করুন
৪. দাম আর সাইজ ঠিক করে সেভ করুন
৫. ১০-১৫টা জুতা যোগ করুন
```

#### Afternoon (2 hours)
**Add Store Content**
```
Codex-এ বলুন:
"Update content:
- About page with store story
- Contact page with map
- FAQ page (common questions)
- Terms page (simple)"
```

#### Evening (1 hour)
**Final Review**
```
১. পুরো সাইট ব্রাউজ করুন
২. Admin panel চেক করুন
৩. মোবাইলে চেক করুন
```

---

### 🟢 DAY 13: Deployment

#### Morning (2 hours)
**Step 1: Deploy to Vercel**
```bash
# Codex terminal:
npx vercel

# Follow prompts:
# - Login with GitHub/Vercel account
# - Link to project
# - Deploy
```

**Step 2: Add Custom Domain (Optional)**
```
১. Vercel dashboard → Domains
২. Add domain: airdokan.com (if bought)
৩. Or use free vercel.app domain
```

#### Afternoon (2 hours)
**Step 3: Production Database**
```
১. Supabase → Project Settings
২. Check if production database has data
৩. If not, migrate local data
```

**Step 4: Environment Variables**
```
১. Vercel → Project Settings → Environment Variables
২. Add all variables from .env.local
৩. Redeploy if needed
```

#### Evening (1 hour)
**Step 5: Live Testing**
```
১. Live URL দিয়ে সব টেস্ট করুন
২. মোবাইলে টেস্ট করুন
৩. Speed test করুন (pagespeed.web.dev)
```

---

### 🟢 DAY 14: Launch & Training

#### Morning (2 hours)
**Prepare for Abbu**
```
১. Admin panel এর স্ক্রিনশট নিন
২. Simple user guide লিখুন (Bangla):
   - কিভাবে লগইন করবেন
   - কিভাবে ছবি তুলবেন
   - কিভাবে সেভ করবেন
   - কিভাবে স্টক আপডেট করবেন
```

**Create Quick Reference Card**
```
┌─────────────────────────────┐
│     Air Dokan - Quick Guide  │
├─────────────────────────────┤
│ ১. অ্যাপ খুলুন               │
│ ২. "নতুন জুতা" তে ট্যাপ করুন  │
│ ৩. ছবি তুলুন                 │
│ ৪. "AI বিশ্লেষণ" তে ট্যাপ করুন│
│ ৫. দাম ঠিক করে "সেভ" করুন    │
├─────────────────────────────┤
│ স্টক আপডেট:                  │
│ "স্টক" → জুতা সিলেক্ট →      │
│ নতুন সংখ্যা লিখুন → সেভ      │
├─────────────────────────────┤
│ হেল্প: [আপনার ফোন নম্বর]      │
└─────────────────────────────┘
```

#### Afternoon (2 hours)
**Train Abbu (Video Call)**
```
১. Imo/WhatsApp video call
২. Screen share করে দেখান
৩. প্রথম ১-২টা জুতা একসাথে যোগ করুন
৪. স্টক আপডেট প্র্যাকটিস করান
৫. প্রশ্ন জিজ্ঞেস করুন
```

#### Evening (1 hour)
**Launch! 🎉**
```
১. Facebook/WhatsApp status দিন
২. কাস্টমারদের লিংক শেয়ার করুন
৩. QR code প্রিন্ট করে দোকানে লাগান
৪. First order celebrate করুন!
```

---

## 📱 Abbu's Daily Routine (After Launch)

### Morning (5 minutes)
```
১. অ্যাপ খুলুন
২. "আজকের সারাংশ" দেখুন
৩. লো স্টক থাকলে WhatsApp এ আপনাকে জানান
```

### New Shoe Arrives (5 minutes)
```
১. "নতুন জুতা" তে ট্যাপ
২. ছবি তুলুন (১-২টি)
৩. AI auto-fill দেখুন
৪. দাম আর সাইজ ঠিক করুন
৫. "সেভ" করুন
```

### Sale Happens (10 seconds)
```
১. "বিক্রি" তে ট্যাপ
২. জুতা সিলেক্ট করুন
৩. সাইজ সিলেক্ট করুন
৪. "✓" তে ট্যাপ
```

### Evening (2 minutes)
```
১. আজকের বিক্রি দেখুন
২. স্টক চেক করুন
৩. প্রয়োজনে আপনাকে কল করুন
```

---

## 🆘 Troubleshooting Guide

### Problem: Photo upload fails
```
Solution:
১. Check internet connection
২. Photo size < 5MB
৩. Try smaller photo
৪. Refresh page
```

### Problem: AI analysis wrong
```
Solution:
১. Tap field to edit
২. Correct the info
৩. Save anyway
৪. Better photo next time
```

### Problem: Stock not updating
```
Solution:
১. Check internet
২. Refresh page
৩. Try again
৪. Call you if still problem
```

### Problem: Forgot password
```
Solution:
১. Call you
২. You reset from Supabase dashboard
৩. Give new password to Abbu
```

---

## 📞 Your Support Role (From Sylhet)

### Weekly (Every Friday)
```
১. Call Abbu, ask how it's going
২. Check website analytics
৩. Update any new features
৪. Fix any issues
```

### Monthly (When visiting home)
```
১. Take photos of new collection
২. Update website design if needed
৩. Train Abbu on new features
৪. Backup database
```

### Emergency
```
১. Abbu calls you
২. You login to admin remotely
৩. Fix issue via Codex
৪. Deploy update
```

---

## ✅ Success Metrics

After 1 month:
- [ ] 50+ shoes in catalog
- [ ] 10+ daily visitors
- [ ] 5+ WhatsApp orders/week
- [ ] Abbu can add shoes independently
- [ ] Zero stock mismatches

After 3 months:
- [ ] 200+ shoes in catalog
- [ ] 50+ daily visitors
- [ ] 20+ orders/week
- [ ] Abbu fully comfortable
- [ ] Considering expansion

---

## 🎓 Learning Resources (If Stuck)

| Topic | Resource |
|-------|----------|
| Next.js | nextjs.org/docs |
| Supabase | supabase.com/docs |
| Tailwind CSS | tailwindcss.com/docs |
| ChatGPT Codex | Ask "How to..." in Codex |
| Bangladesh Dev Community | Facebook groups |

---

**Plan Version:** 3.0  
**Focus:** ChatGPT Plus + Codex Only  
**Timeline:** 14 Days  
**Budget:** $20/month (Plus subscription only)  
**Target:** Katakhal Bazar, Mithamin, Kishoreganj

---

*"আব্বু শুধু ছবি তুলবেন, বাকি সব AI করবে — আর আপনি সিলেট থেকে ম্যানেজ করবেন"*
