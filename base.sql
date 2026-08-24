-- 1. Criação do Banco de Dados
CREATE DATABASE SistemaRestaurante;
GO

USE SistemaRestaurante;
GO

-- 2. Tabela de Usuários (RF01, RF02)
CREATE TABLE Usuarios (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    Nome VARCHAR(100) NOT NULL,
    Login VARCHAR(50) NOT NULL UNIQUE,
    SenhaHash VARCHAR(256) NOT NULL, -- Suporta HASH SHA-256 (RNF04)
    Nivel_Permissao VARCHAR(20) NOT NULL CHECK (Nivel_Permissao IN ('Administrador', 'Gerente', 'Garcom', 'Caixa')),
    Ativo BIT DEFAULT 1 NOT NULL
);

-- 3. Tabela de Produtos / Estoque (RF03)
CREATE TABLE Produtos_Estoque (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    Nome VARCHAR(100) NOT NULL,
    Descricao VARCHAR(255),
    Quantidade_Atual INT NOT NULL DEFAULT 0,
    Preco_Custo DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    Preco_Venda DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    Ativo BIT DEFAULT 1 NOT NULL
);

-- 4. Tabela de Movimentação de Estoque (RF03, RF05)
CREATE TABLE Movimentacao_Estoque (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    Produto_ID INT NOT NULL,
    Usuario_ID INT NOT NULL,
    Tipo_Movimentacao VARCHAR(10) NOT NULL CHECK (Tipo_Movimentacao IN ('Entrada', 'Saida')),
    Quantidade INT NOT NULL CHECK (Quantidade > 0),
    DataMovimentacao DATETIME DEFAULT GETDATE() NOT NULL,
    Observacao VARCHAR(255),
    CONSTRAINT FK_MovEstoque_Produto FOREIGN KEY (Produto_ID) REFERENCES Produtos_Estoque(ID),
    CONSTRAINT FK_MovEstoque_Usuario FOREIGN KEY (Usuario_ID) REFERENCES Usuarios(ID)
);

-- 5. Tabela de Categorias Financeiras (Apoio ao RF04/RF05)
CREATE TABLE Categorias_Financeiras (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    Nome VARCHAR(50) NOT NULL,
    Tipo VARCHAR(10) NOT NULL CHECK (Tipo IN ('Entrada', 'Saida'))
);

-- 6. Tabela de Movimentação Financeira (RF04, RF05)
CREATE TABLE Movimentacao_Financeira (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    Usuario_ID INT NOT NULL,
    Categoria_ID INT NOT NULL,
    Tipo VARCHAR(10) NOT NULL CHECK (Tipo IN ('Entrada', 'Saida')),
    Descricao VARCHAR(255) NOT NULL,
    Valor DECIMAL(10, 2) NOT NULL CHECK (Valor > 0),
    DataMovimentacao DATETIME DEFAULT GETDATE() NOT NULL,
    Situacao VARCHAR(10) NOT NULL DEFAULT 'Pago' CHECK (Situacao IN ('Pago', 'Pendente', 'Cancelado')),
    CONSTRAINT FK_MovFinanceira_Usuario FOREIGN KEY (Usuario_ID) REFERENCES Usuarios(ID),
    CONSTRAINT FK_MovFinanceira_Categoria FOREIGN KEY (Categoria_ID) REFERENCES Categorias_Financeiras(ID)
);