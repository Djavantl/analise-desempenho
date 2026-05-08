-- Tabela compartilhada pelas duas APIs (Laravel e Django)
-- Adicione os produtos via INSERT abaixo ou após o container subir.

CREATE TABLE IF NOT EXISTS items (
    id          BIGSERIAL PRIMARY KEY,
    name        VARCHAR(255)    NOT NULL,
    description TEXT,
    price       DECIMAL(10, 2)  NOT NULL,
    created_at  TIMESTAMPTZ     DEFAULT NOW(),
    updated_at  TIMESTAMPTZ     DEFAULT NOW()
);

-- Exemplo (descomente para popular):
-- INSERT INTO items (name, description, price) VALUES
--   ('Produto 1', 'Descrição do produto 1', 19.90),
--   ('Produto 2', 'Descrição do produto 2', 49.90);
