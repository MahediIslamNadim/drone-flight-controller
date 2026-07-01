"use client";

import type { Dispatch, FormEvent, SetStateAction } from "react";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { LoaderCircle, Sparkles, UploadCloud, X } from "lucide-react";
import type { Brand, Category, Shoe } from "@/lib/types";

type AdminShoeFormProps = {
  brands: Brand[];
  categories: Category[];
  initialShoe?: Shoe;
  mode?: "create" | "edit";
};

type PreviewFile = {
  id: string;
  file: File;
  previewUrl: string;
  progress: number;
};

type SavedShoePreview = {
  shoeId?: string;
  mode?: string;
  nameBn: string;
  nameEn: string;
  brandName: string;
  categoryName: string;
  price: number;
  imageUrl?: string;
  totalSizes: number;
};

type SizeSelection = Record<string, number>;

const sizeOptions = ["36", "37", "38", "39", "40", "41", "42", "43", "44"];
const colorOptions = ["Black", "Brown", "Tan", "White", "Red", "Blue", "Grey"];
const materialOptions = ["Leather", "Synthetic", "Mesh", "Foam", "Rubber", "Canvas"];
const styleOptions = ["Formal", "Casual", "Running", "Sandal", "Slide", "Boot"];
const genderOptions = ["Men", "Women", "Unisex", "Kids"];

function toInitialSizeState() {
  return sizeOptions.reduce<SizeSelection>((accumulator, size) => {
    accumulator[size] = 0;
    return accumulator;
  }, {});
}

export function AdminShoeForm({
  brands,
  categories,
  initialShoe,
  mode = "create",
}: AdminShoeFormProps) {
  const router = useRouter();
  const [files, setFiles] = useState<PreviewFile[]>([]);
  const [coverFileId, setCoverFileId] = useState<string | null>(null);
  const [currentImageUrls, setCurrentImageUrls] = useState<string[]>(initialShoe?.imageUrls ?? []);
  const [nameBn, setNameBn] = useState(initialShoe?.nameBn ?? "");
  const [nameEn, setNameEn] = useState(initialShoe?.nameEn ?? "");
  const [brandSlug, setBrandSlug] = useState(initialShoe?.brand.slug ?? brands[0]?.slug ?? "");
  const [categorySlug, setCategorySlug] = useState(
    initialShoe?.category.slug ?? categories[0]?.slug ?? ""
  );
  const [price, setPrice] = useState(initialShoe ? String(initialShoe.price) : "");
  const [selectedColors, setSelectedColors] = useState<string[]>(initialShoe?.colors ?? []);
  const [selectedMaterials, setSelectedMaterials] = useState<string[]>(
    initialShoe?.materials ?? []
  );
  const [styleType, setStyleType] = useState(initialShoe?.styleType ?? styleOptions[0]);
  const [gender, setGender] = useState(initialShoe?.gender ?? genderOptions[0]);
  const [sizes, setSizes] = useState<SizeSelection>(() => {
    const initialState = toInitialSizeState();
    initialShoe?.sizes.forEach((size) => {
      initialState[size.size] = size.stockQuantity;
    });
    return initialState;
  });
  const [statusMessage, setStatusMessage] = useState("");
  const [errorMessage, setErrorMessage] = useState("");
  const [isSaving, setIsSaving] = useState(false);
  const [lastSaved, setLastSaved] = useState<SavedShoePreview | null>(null);

  useEffect(() => {
    return () => {
      files.forEach((file) => URL.revokeObjectURL(file.previewUrl));
    };
  }, [files]);

  const activeSizes = useMemo(
    () =>
      Object.entries(sizes)
        .filter(([, stockQuantity]) => stockQuantity > 0)
        .map(([size, stockQuantity]) => ({ size, stockQuantity })),
    [sizes]
  );

  function toggleValue(
    setter: Dispatch<SetStateAction<string[]>>,
    value: string
  ) {
    setter((previous) =>
      previous.includes(value)
        ? previous.filter((item) => item !== value)
        : [...previous, value]
    );
  }

  function handleFiles(selectedFiles: FileList | null) {
    if (!selectedFiles) {
      return;
    }

    setStatusMessage("");
    const nextFiles = Array.from(selectedFiles)
      .slice(0, 3)
      .map((file) => ({
        id: `${file.name}-${file.lastModified}`,
        file,
        previewUrl: URL.createObjectURL(file),
        progress: 15,
      }));

    setFiles((previous) => {
      previous.forEach((file) => URL.revokeObjectURL(file.previewUrl));
      return nextFiles;
    });
    setCoverFileId(nextFiles[0]?.id ?? null);

    nextFiles.forEach((preview) => {
      let progress = 15;
      const interval = window.setInterval(() => {
        progress += 20;

        setFiles((current) =>
          current.map((item) =>
            item.id === preview.id
              ? {
                  ...item,
                  progress: Math.min(progress, 100),
                }
              : item
          )
        );

        if (progress >= 100) {
          window.clearInterval(interval);
        }
      }, 120);
    });
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setIsSaving(true);
    setErrorMessage("");
    setStatusMessage("");

    try {
      let imageUrls = [...currentImageUrls];
      const orderedFiles = files.length
        ? [
            ...files.filter((file) => file.id === coverFileId),
            ...files.filter((file) => file.id !== coverFileId),
          ]
        : [];

      if (orderedFiles.length > 0) {
        setStatusMessage("Uploading photos...");
        const uploadFormData = new FormData();

        orderedFiles.forEach((file) => {
          uploadFormData.append("files", file.file);
        });

        const uploadResponse = await fetch("/api/admin/uploads", {
          method: "POST",
          body: uploadFormData,
        });

        const uploadResult = (await uploadResponse.json()) as {
          error?: string;
          urls?: string[];
        };

        if (!uploadResponse.ok || !uploadResult.urls) {
          setErrorMessage(uploadResult.error ?? "Could not upload shoe images.");
          return;
        }

        imageUrls = uploadResult.urls;
      }

      setStatusMessage("Saving shoe...");
      const endpoint =
        mode === "edit" && initialShoe ? `/api/admin/shoes/${initialShoe.id}` : "/api/admin/shoes";
      const response = await fetch(endpoint, {
        method: mode === "edit" ? "PUT" : "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          brandSlug,
          categorySlug,
          nameBn,
          nameEn,
          price: Number(price),
          colors: selectedColors,
          materials: selectedMaterials,
          styleType,
          gender,
          imageUrls,
          sizes: activeSizes,
        }),
      });

      const result = (await response.json()) as {
        message?: string;
        error?: string;
        shoeId?: string;
        mode?: string;
      };

      if (!response.ok) {
        setErrorMessage(result.error ?? "Could not save shoe.");
        return;
      }

      setLastSaved({
        shoeId: result.shoeId,
        mode: result.mode,
        nameBn,
        nameEn,
        brandName: brands.find((brand) => brand.slug === brandSlug)?.name ?? brandSlug,
        categoryName:
          categories.find((category) => category.slug === categorySlug)?.name ?? categorySlug,
        price: Number(price),
        imageUrl: imageUrls[0] ?? files[0]?.previewUrl,
        totalSizes: activeSizes.length,
      });
      setStatusMessage(
        result.message ?? (mode === "edit" ? "Shoe updated." : "Shoe saved.")
      );
      if (mode === "create") {
        setNameBn("");
        setNameEn("");
        setPrice("");
        setSelectedColors([]);
        setSelectedMaterials([]);
        setStyleType(styleOptions[0]);
        setGender(genderOptions[0]);
        setSizes(toInitialSizeState());
        setCoverFileId(null);
        setCurrentImageUrls([]);
      } else {
        setCurrentImageUrls(imageUrls);
      }
      setFiles((current) => {
        current.forEach((file) => URL.revokeObjectURL(file.previewUrl));
        return [];
      });
      setCoverFileId(null);
      router.refresh();
    } catch {
      setErrorMessage("Save request failed. Please try again.");
    } finally {
      setIsSaving(false);
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      <section className="rounded-[2rem] border border-white/70 bg-white/85 p-5 shadow-sm">
        <div className="flex items-center gap-3">
          <span className="grid h-11 w-11 place-items-center rounded-2xl bg-pine/10 text-pine">
            <UploadCloud className="h-5 w-5" />
          </span>
          <div>
            <h2 className="font-[family-name:var(--font-heading)] text-2xl font-bold text-ink">
              1. Photo upload
            </h2>
            <p className="text-sm text-ink/65">Front, side, ar detail photo diye din.</p>
          </div>
        </div>

        <label className="mt-5 block cursor-pointer rounded-[1.75rem] border-2 border-dashed border-pine/20 bg-mist px-5 py-8 text-center transition hover:border-pine/35">
          <input
            type="file"
            accept="image/*"
            multiple
            className="hidden"
            onChange={(event) => handleFiles(event.target.files)}
          />
          <p className="font-semibold text-pine">Drag & drop na hole click kore photo din</p>
          <p className="mt-2 text-sm text-ink/60">Maximum 3 ta photo. Preview ekhanei dekhaben.</p>
          <p className="mt-2 text-xs text-ink/45">
            Supabase configure thakle actual image upload hobe.
          </p>
        </label>

        {files.length > 0 ? (
          <div className="mt-5 grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
            {files.map((file) => (
              <div key={file.id} className="overflow-hidden rounded-[1.5rem] border border-pine/10 bg-white">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={file.previewUrl}
                  alt={file.file.name}
                  className="h-48 w-full object-cover"
                />
                <div className="space-y-2 p-4">
                  <div className="flex items-start justify-between gap-3">
                    <div>
                      <p className="line-clamp-2 text-sm font-medium text-ink">{file.file.name}</p>
                      <p className="mt-1 text-xs text-ink/50">
                        {coverFileId === file.id ? "Cover image for catalog" : "Additional view"}
                      </p>
                    </div>
                    <div className="flex items-center gap-2">
                      <button
                        type="button"
                        onClick={() => setCoverFileId(file.id)}
                        className={`rounded-full px-3 py-1 text-xs font-semibold transition ${
                          coverFileId === file.id
                            ? "bg-pine text-white"
                            : "border border-pine/10 text-pine hover:border-pine/25"
                        }`}
                      >
                        {coverFileId === file.id ? "Cover" : "Set cover"}
                      </button>
                      <button
                        type="button"
                        onClick={() =>
                          setFiles((current) => {
                            const selected = current.find((item) => item.id === file.id);
                            if (selected) {
                              URL.revokeObjectURL(selected.previewUrl);
                            }

                            const remainingFiles = current.filter((item) => item.id !== file.id);
                            if (coverFileId === file.id) {
                              setCoverFileId(remainingFiles[0]?.id ?? null);
                            }

                            return remainingFiles;
                          })
                        }
                        className="rounded-full p-1 text-ink/45 transition hover:bg-ink/5 hover:text-ink"
                      >
                        <X className="h-4 w-4" />
                      </button>
                    </div>
                  </div>
                  <div className="h-2 rounded-full bg-ink/10">
                    <div
                      className="h-2 rounded-full bg-pine transition-all"
                      style={{ width: `${file.progress}%` }}
                    />
                  </div>
                  <p className="text-xs text-ink/55">{file.progress}% uploaded</p>
                </div>
              </div>
            ))}
          </div>
        ) : null}

        {currentImageUrls.length > 0 && files.length === 0 ? (
          <div className="mt-5">
            <p className="mb-3 text-sm font-medium text-ink/75">Current catalog photos</p>
            <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
              {currentImageUrls.map((imageUrl, index) => (
                <div
                  key={`${imageUrl}-${index}`}
                  className="overflow-hidden rounded-[1.5rem] border border-pine/10 bg-white"
                >
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    src={imageUrl}
                    alt={`Current shoe image ${index + 1}`}
                    className="h-48 w-full object-cover"
                  />
                  <div className="p-4 text-xs text-ink/55">
                    {index === 0 ? "Current cover image" : "Current additional image"}
                  </div>
                </div>
              ))}
            </div>
          </div>
        ) : null}
      </section>

      <section className="rounded-[2rem] border border-white/70 bg-white/85 p-5 shadow-sm">
        <div className="flex items-center gap-3">
          <span className="grid h-11 w-11 place-items-center rounded-2xl bg-ember/10 text-ember">
            <Sparkles className="h-5 w-5" />
          </span>
          <div>
            <h2 className="font-[family-name:var(--font-heading)] text-2xl font-bold text-ink">
              2. AI analysis section
            </h2>
            <p className="text-sm text-ink/65">
              Manual first pass. Pore AI auto-fill ekhane bosano jabe.
            </p>
          </div>
        </div>

        <div className="mt-5 grid gap-4 md:grid-cols-2">
          <FieldSelect
            label="Brand"
            value={brandSlug}
            onChange={setBrandSlug}
            options={brands.map((brand) => ({ label: brand.name, value: brand.slug }))}
          />
          <FieldSelect
            label="Category"
            value={categorySlug}
            onChange={setCategorySlug}
            options={categories.map((category) => ({
              label: category.name,
              value: category.slug,
            }))}
          />
          <FieldInput label="Name (Bangla)" value={nameBn} onChange={setNameBn} />
          <FieldInput label="Name (English)" value={nameEn} onChange={setNameEn} />
          <FieldInput
            label="Price"
            value={price}
            onChange={setPrice}
            type="number"
            placeholder="3290"
          />
          <FieldSelect
            label="Style"
            value={styleType}
            onChange={setStyleType}
            options={styleOptions.map((option) => ({ label: option, value: option }))}
          />
          <FieldSelect
            label="Gender"
            value={gender}
            onChange={setGender}
            options={genderOptions.map((option) => ({ label: option, value: option }))}
          />
        </div>

        <OptionGroup
          label="Colors"
          values={selectedColors}
          options={colorOptions}
          onToggle={(value) => toggleValue(setSelectedColors, value)}
        />
        <OptionGroup
          label="Materials"
          values={selectedMaterials}
          options={materialOptions}
          onToggle={(value) => toggleValue(setSelectedMaterials, value)}
        />
      </section>

      <section className="rounded-[2rem] border border-white/70 bg-white/85 p-5 shadow-sm">
        <div>
          <h2 className="font-[family-name:var(--font-heading)] text-2xl font-bold text-ink">
            3. Size & stock
          </h2>
          <p className="mt-1 text-sm text-ink/65">
            Je size ache, oi size-r quantity diye din.
          </p>
        </div>

        <div className="mt-5 grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          {sizeOptions.map((size) => {
            const stockQuantity = sizes[size];
            const indicatorClass =
              stockQuantity === 0
                ? "bg-ink/10 text-ink/45"
                : stockQuantity < 3
                  ? "bg-amber-100 text-amber-700"
                  : "bg-emerald-100 text-emerald-700";

            return (
              <div
                key={size}
                className="rounded-[1.5rem] border border-pine/10 bg-white p-4"
              >
                <div className="flex items-center justify-between gap-3">
                  <div>
                    <p className="font-[family-name:var(--font-heading)] text-2xl font-bold text-ink">
                      {size}
                    </p>
                    <p className="text-sm text-ink/55">Size</p>
                  </div>
                  <span
                    className={`rounded-full px-3 py-1 text-xs font-semibold ${indicatorClass}`}
                  >
                    {stockQuantity === 0
                      ? "Out"
                      : stockQuantity < 3
                        ? "Low"
                        : "Good"}
                  </span>
                </div>

                <label className="mt-4 block">
                  <span className="mb-2 block text-sm font-medium text-ink/70">
                    Quantity
                  </span>
                  <input
                    type="number"
                    min="0"
                    value={stockQuantity}
                    onChange={(event) =>
                      setSizes((current) => ({
                        ...current,
                        [size]: Number(event.target.value),
                      }))
                    }
                    className="w-full rounded-2xl border border-pine/10 bg-mist px-4 py-3 text-base text-ink"
                  />
                </label>
              </div>
            );
          })}
        </div>
      </section>

      {errorMessage ? (
        <p className="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {errorMessage}
        </p>
      ) : null}

      {statusMessage ? (
        <p className="rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">
          {statusMessage}
        </p>
      ) : null}

      {lastSaved ? (
        <section className="rounded-[2rem] border border-emerald-200 bg-emerald-50/70 p-5 shadow-sm">
          <p className="text-sm uppercase tracking-[0.22em] text-emerald-700">Saved Preview</p>
          <div className="mt-4 flex flex-col gap-4 sm:flex-row">
            {lastSaved.imageUrl ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={lastSaved.imageUrl}
                alt={lastSaved.nameEn}
                className="h-32 w-full rounded-[1.5rem] object-cover sm:w-40"
              />
            ) : null}
            <div className="space-y-2">
              <p className="font-[family-name:var(--font-heading)] text-2xl font-bold text-ink">
                {lastSaved.nameEn}
              </p>
              <p className="text-sm text-ink/65">{lastSaved.nameBn}</p>
              <p className="text-sm text-ink/70">
                {lastSaved.brandName} • {lastSaved.categoryName}
              </p>
              <p className="text-sm font-semibold text-pine">
                Tk {Math.round(lastSaved.price).toLocaleString("en-US")}
              </p>
              <p className="text-sm text-ink/70">
        {lastSaved.totalSizes} size selected • {lastSaved.mode === "mock" ? "Mock mode" : "Saved to catalog"}
              </p>
            </div>
          </div>
        </section>
      ) : null}

      <button
        type="submit"
        disabled={isSaving}
        className="inline-flex w-full items-center justify-center gap-2 rounded-full bg-pine px-6 py-4 text-base font-semibold text-white transition hover:bg-pine/90 disabled:cursor-not-allowed disabled:opacity-70"
      >
        {isSaving ? <LoaderCircle className="h-5 w-5 animate-spin" /> : null}
        {mode === "edit" ? "Update shoe" : "Save shoe"}
      </button>
    </form>
  );
}

function FieldInput({
  label,
  value,
  onChange,
  type = "text",
  placeholder,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  type?: string;
  placeholder?: string;
}) {
  return (
    <label className="block">
      <span className="mb-2 block text-sm font-medium text-ink/75">{label}</span>
      <input
        type={type}
        value={value}
        onChange={(event) => onChange(event.target.value)}
        placeholder={placeholder}
        className="w-full rounded-2xl border border-pine/10 bg-mist px-4 py-3 text-base text-ink outline-none"
        required
      />
    </label>
  );
}

function FieldSelect({
  label,
  value,
  onChange,
  options,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  options: Array<{ label: string; value: string }>;
}) {
  return (
    <label className="block">
      <span className="mb-2 block text-sm font-medium text-ink/75">{label}</span>
      <select
        value={value}
        onChange={(event) => onChange(event.target.value)}
        className="w-full rounded-2xl border border-pine/10 bg-mist px-4 py-3 text-base text-ink outline-none"
      >
        {options.map((option) => (
          <option key={option.value} value={option.value}>
            {option.label}
          </option>
        ))}
      </select>
    </label>
  );
}

function OptionGroup({
  label,
  options,
  values,
  onToggle,
}: {
  label: string;
  options: string[];
  values: string[];
  onToggle: (value: string) => void;
}) {
  return (
    <div className="mt-5">
      <p className="mb-3 text-sm font-medium text-ink/75">{label}</p>
      <div className="flex flex-wrap gap-3">
        {options.map((option) => {
          const active = values.includes(option);

          return (
            <button
              key={option}
              type="button"
              onClick={() => onToggle(option)}
              className={`rounded-full px-4 py-2 text-sm font-semibold transition ${
                active
                  ? "bg-pine text-white"
                  : "border border-pine/10 bg-white text-ink/75 hover:border-pine/25"
              }`}
            >
              {option}
            </button>
          );
        })}
      </div>
    </div>
  );
}
