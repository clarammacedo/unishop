-- Seed das categorias fixas (RN-CAT-01), repetível. A conta admin NÃO entra aqui:
-- ela nasce do seed do backend (prisma/seed.ts) com ADMIN_EMAIL e ADMIN_PASSWORD (RN-ADM-11).
INSERT INTO public.categoria (nome) VALUES
  ('Livros e apostilas'), ('Eletrônicos'), ('Alimentos'),
  ('Materiais de curso'), ('Vestuário'), ('Outros')
ON CONFLICT (nome) DO NOTHING;
