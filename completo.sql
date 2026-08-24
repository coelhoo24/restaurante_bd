--1. CRIAR O BANCO
CREATE DATABASE SistemaRestaurante;
GO

USE SistemaRestaurante;
GO


-- 2. TABELAS, PKs e FKs (Integridade Referencial)
CREATE TABLE Usuarios (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    Nome VARCHAR(100) NOT NULL,
    Login VARCHAR(50) NOT NULL UNIQUE,
    SenhaHash VARCHAR(256) NOT NULL,
    Nivel_Permissao VARCHAR(20) NOT NULL CHECK (Nivel_Permissao IN ('Administrador', 'Gerente', 'Garcom', 'Caixa')),
    Ativo BIT DEFAULT 1 NOT NULL
);

CREATE TABLE Produtos_Estoque (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    Nome VARCHAR(100) NOT NULL,
    Descricao VARCHAR(255),
    Quantidade_Atual INT NOT NULL DEFAULT 0,
    Preco_Custo DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    Preco_Venda DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    Ativo BIT DEFAULT 1 NOT NULL
);

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

CREATE TABLE Categorias_Financeiras (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    Nome VARCHAR(50) NOT NULL,
    Tipo VARCHAR(10) NOT NULL CHECK (Tipo IN ('Entrada', 'Saida'))
);

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
GO

-- 3. ÍNDICES (p otimização de Performance)

-- Índices em colunas frequentemente usadas em filtros (WHERE) ou ordenações
CREATE INDEX IX_Usuarios_Login ON Usuarios(Login);
CREATE INDEX IX_Produtos_Nome ON Produtos_Estoque(Nome);
CREATE INDEX IX_MovEstoque_Data ON Movimentacao_Estoque(DataMovimentacao);
CREATE INDEX IX_MovFinanceira_Data ON Movimentacao_Financeira(DataMovimentacao);
GO


-- 4. TRIGGERS (Automatização e Integridade de Negócio)
-- Justificativa: Atualiza automaticamente o estoque (Quantidade_Atual) 
-- sempre que houver uma entrada ou saída registrada.

CREATE TRIGGER TRG_AtualizaEstoque
ON Movimentacao_Estoque
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Se for 'Entrada', soma ao estoque. Se for 'Saida', subtrai.
    UPDATE p
    SET p.Quantidade_Atual = CASE 
        WHEN i.Tipo_Movimentacao = 'Entrada' THEN p.Quantidade_Atual + i.Quantidade
        WHEN i.Tipo_Movimentacao = 'Saida' THEN p.Quantidade_Atual - i.Quantidade
    END
    FROM Produtos_Estoque p
    INNER JOIN inserted i ON p.ID = i.Produto_ID;
END;
GO

-- 5. PROCEDURES (Rotinas Armazenadas)

-- Procedure para registrar uma movimentação de estoque com segurança transacional
CREATE PROCEDURE SP_RegistrarMovimentacaoEstoque
    @Produto_ID INT,
    @Usuario_ID INT,
    @Tipo_Movimentacao VARCHAR(10),
    @Quantidade INT,
    @Observacao VARCHAR(255)
AS
BEGIN
    BEGIN TRANSACTION;
    BEGIN TRY
        INSERT INTO Movimentacao_Estoque (Produto_ID, Usuario_ID, Tipo_Movimentacao, Quantidade, Observacao)
        VALUES (@Produto_ID, @Usuario_ID, @Tipo_Movimentacao, @Quantidade, @Observacao);
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- 6. VIEWS (Visões para Relatórios)

-- View para exibir o resumo do fluxo de caixa com dados legíveis
CREATE VIEW VW_ExtratoFinanceiro AS
    SELECT 
        mf.ID,
        mf.DataMovimentacao,
        mf.Tipo,
        cf.Nome AS Categoria,
        mf.Descricao,
        mf.Valor,
        mf.Situacao,
        u.Nome AS UsuarioResponsavel
    FROM Movimentacao_Financeira mf
    INNER JOIN Categorias_Financeiras cf ON mf.Categoria_ID = cf.ID
    INNER JOIN Usuarios u ON mf.Usuario_ID = u.ID;
GO

-- 7. CONSULTAS COM JOIN (Exemplo Prático)

-- Consulta que lista todas as movimentações de estoque junto com o nome do produto e do usuário
SELECT 
    me.ID AS ID_Movimentacao,
    p.Nome AS Produto,
    me.Tipo_Movimentacao,
    me.Quantidade,
    me.DataMovimentacao,
    u.Nome AS Usuario_Responsavel
FROM Movimentacao_Estoque me
INNER JOIN Produtos_Estoque p ON me.Produto_ID = p.ID
INNER JOIN Usuarios u ON me.Usuario_ID = u.ID;
GO

-- 8. CONTROLE DE USUÁRIOS E PERMISSÕES (DCL)

-- Criação de logins no nível do Servidor e usuários no nível do Banco de Dados
CREATE LOGIN GerenteLogin WITH PASSWORD = 'SenhaForteGerente123!';
CREATE LOGIN GarcomLogin WITH PASSWORD = 'SenhaForteGarcom123!';
GO

CREATE USER GerenteUser FOR LOGIN GerenteLogin;
CREATE USER GarcomUser FOR LOGIN GarcomLogin;
GO

-- Atribuindo permissões específicas baseadas no papel operacional
-- Gerente pode ler e escrever em todas as tabelas principais
GRANT SELECT, INSERT, UPDATE ON Produtos_Estoque TO GerenteUser;
GRANT SELECT, INSERT ON Movimentacao_Estoque TO GerenteUser;
GRANT SELECT, INSERT, UPDATE ON Movimentacao_Financeira TO GerenteUser;

-- Garçom tem acesso restrito apenas para consultar produtos e registrar estoque
GRANT SELECT ON Produtos_Estoque TO GarcomUser;
GRANT SELECT, INSERT ON Movimentacao_Estoque TO GarcomUser;
GO

-- 9. ROTINA DE BACKUP

-- Comando padrão para realizar o backup completo do banco de dados do restaurante
BACKUP DATABASE SistemaRestaurante
TO DISK = 'C:\Backup\SistemaRestaurante_Completo.bak'
WITH FORMAT,
     MEDIANAME = 'SQLServerBackups',
     NAME = 'Backup Completo - SistemaRestaurante';
GO