-- =====================================================================
-- SistemaRestaurante
-- Pode ser executado mais de uma vez sem dar erro: cada bloco checa se
-- o objeto já existe antes de criar (IF OBJECT_ID / IF NOT EXISTS).
--
-- tem tds os requisitos do projeto
--   - tabelas relacionadas c/ PK, FK e CHECK constraints
--   - indices
--   - Trigger de automação (estoque)
--   - Procedures (estoque e financeiro), com transação e rollback
--   - Views para os 5 relatórios obrigatórios
--   - Controle de usuários e permissões (DCL)
--   - Rotina de backup
-- =====================================================================

IF DB_ID('SistemaRestaurante') IS NULL
BEGIN
    CREATE DATABASE SistemaRestaurante;
END;
GO

USE SistemaRestaurante;
GO


-- =====================================================================
-- 1. TABELAS
-- =====================================================================

IF OBJECT_ID('Usuarios', 'U') IS NULL
BEGIN
    CREATE TABLE Usuarios (
        ID INT IDENTITY(1,1) PRIMARY KEY,
        Nome VARCHAR(100) NOT NULL,
        Login VARCHAR(50) NOT NULL UNIQUE,
        SenhaHash VARCHAR(256) NOT NULL, -- Suporta HASH SHA-256 (RNF04)
        Nivel_Permissao VARCHAR(20) NOT NULL CHECK (Nivel_Permissao IN ('Administrador', 'Gerente', 'Garcom', 'Caixa')),
        Ativo BIT DEFAULT 1 NOT NULL
    );
END;
GO

IF OBJECT_ID('Produtos_Estoque', 'U') IS NULL
BEGIN
    CREATE TABLE Produtos_Estoque (
        ID INT IDENTITY(1,1) PRIMARY KEY,
        Nome VARCHAR(100) NOT NULL,
        Descricao VARCHAR(255),
        Quantidade_Atual INT NOT NULL DEFAULT 0,
        Preco_Custo DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
        Preco_Venda DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
        Ativo BIT DEFAULT 1 NOT NULL
    );
END;
GO

IF OBJECT_ID('Movimentacao_Estoque', 'U') IS NULL
BEGIN
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
END;
GO

IF OBJECT_ID('Categorias_Financeiras', 'U') IS NULL
BEGIN
    CREATE TABLE Categorias_Financeiras (
        ID INT IDENTITY(1,1) PRIMARY KEY,
        Nome VARCHAR(50) NOT NULL,
        Tipo VARCHAR(10) NOT NULL CHECK (Tipo IN ('Entrada', 'Saida'))
    );
END;
GO

IF OBJECT_ID('Movimentacao_Financeira', 'U') IS NULL
BEGIN
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
END;
GO


-- =====================================================================
-- 2. ÍNDICES
--com checagem para não duplicar)
-- =====================================================================

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Usuarios_Login')
    CREATE INDEX IX_Usuarios_Login ON Usuarios(Login);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Produtos_Nome')
    CREATE INDEX IX_Produtos_Nome ON Produtos_Estoque(Nome);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_MovEstoque_Data')
    CREATE INDEX IX_MovEstoque_Data ON Movimentacao_Estoque(DataMovimentacao);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_MovFinanceira_Data')
    CREATE INDEX IX_MovFinanceira_Data ON Movimentacao_Financeira(DataMovimentacao);
GO


-- =====================================================================
-- 3. TRIGGERS
-- ============================================================
-- SUMÁRIO:
-- 3.1. TRG_AtualizaEstoque
--      atualiza a Quantidade_Atual do produto sempre que uma
--      movimentação é registrada, e impede a saída se não houver
--      estoque suficiente (regra de negócio).
-- ============================================================

CREATE OR ALTER TRIGGER TRG_AtualizaEstoque
ON Movimentacao_Estoque
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Bloqueia a saída se o estoque atual for menor que a quantidade pedida
    IF EXISTS (
        SELECT 1
        FROM Produtos_Estoque p
        INNER JOIN inserted i ON p.ID = i.Produto_ID
        WHERE i.Tipo_Movimentacao = 'Saida'
          AND p.Quantidade_Atual < i.Quantidade
    )
    BEGIN
        RAISERROR('Estoque insuficiente para registrar a saída.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;

    -- Se passou pela validação, atualiza o estoque (soma na entrada, subtrai na saída)
    UPDATE p
    SET p.Quantidade_Atual = CASE
        WHEN i.Tipo_Movimentacao = 'Entrada' THEN p.Quantidade_Atual + i.Quantidade
        WHEN i.Tipo_Movimentacao = 'Saida' THEN p.Quantidade_Atual - i.Quantidade
    END
    FROM Produtos_Estoque p
    INNER JOIN inserted i ON p.ID = i.Produto_ID;
END;
GO


-- =====================================================================
-- 4. PROCEDURES
-- ============================================================
-- SUMÁRIO:
-- 4.1. SP_RegistrarMovimentacaoEstoque
--      Registra entrada/saída de estoque com transação segura.
--
-- 4.2. SP_RegistrarMovimentacaoFinanceira
--      Registra entrada/saída financeira, validando que a
--      categoria escolhida é compatível com o tipo informado.
-- ============================================================

CREATE OR ALTER PROCEDURE SP_RegistrarMovimentacaoEstoque
    @Produto_ID INT,
    @Usuario_ID INT,
    @Tipo_Movimentacao VARCHAR(10),
    @Quantidade INT,
    @Observacao VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        INSERT INTO Movimentacao_Estoque (Produto_ID, Usuario_ID, Tipo_Movimentacao, Quantidade, Observacao)
        VALUES (@Produto_ID, @Usuario_ID, @Tipo_Movimentacao, @Quantidade, @Observacao);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE SP_RegistrarMovimentacaoFinanceira
    @Usuario_ID INT,
    @Categoria_ID INT,
    @Tipo VARCHAR(10),
    @Descricao VARCHAR(255),
    @Valor DECIMAL(10, 2),
    @Situacao VARCHAR(10) = 'Pago'
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        -- garante que a categoria escolhida é do mesmo Tipo informado
        -- (ex: não deixa lançar uma "Saida" numa categoria de "Entrada")
        IF NOT EXISTS (
            SELECT 1 FROM Categorias_Financeiras
            WHERE ID = @Categoria_ID AND Tipo = @Tipo
        )
        BEGIN
            ROLLBACK TRANSACTION;
            RAISERROR('A categoria informada não corresponde ao tipo (Entrada/Saida) informado.', 16, 1);
            RETURN;
        END;

        INSERT INTO Movimentacao_Financeira (Usuario_ID, Categoria_ID, Tipo, Descricao, Valor, Situacao)
        VALUES (@Usuario_ID, @Categoria_ID, @Tipo, @Descricao, @Valor, @Situacao);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


-- =====================================================================
-- 5. VIEWS - os 5 relatórios obrigatórios do professor
-- =====================================================================

-- 5.1. Relatório: Estoque atual
CREATE OR ALTER VIEW VW_EstoqueAtual AS
    SELECT
        ID,
        Nome,
        Descricao,
        Quantidade_Atual,
        Preco_Custo,
        Preco_Venda
    FROM Produtos_Estoque
    WHERE Ativo = 1;
GO

-- 5.2. Relatório: Movimentação de estoque (histórico de entradas/saídas)
CREATE OR ALTER VIEW VW_MovimentacaoEstoque AS
    SELECT
        me.ID,
        p.Nome AS Produto,
        me.Tipo_Movimentacao,
        me.Quantidade,
        me.DataMovimentacao,
        u.Nome AS Usuario,
        me.Observacao
    FROM Movimentacao_Estoque me
    INNER JOIN Produtos_Estoque p ON me.Produto_ID = p.ID
    INNER JOIN Usuarios u ON me.Usuario_ID = u.ID;
GO

-- View d apoio (extrato completo, usada pelas duas views financeiras abaixo)
CREATE OR ALTER VIEW VW_ExtratoFinanceiro AS
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

-- 5.3. Relatório: entradas financeiras (vendas, recebimentos, outras receitas)
CREATE OR ALTER VIEW VW_EntradasFinanceiras AS
    SELECT * FROM VW_ExtratoFinanceiro WHERE Tipo = 'Entrada';
GO

-- 5.4. Relatório: Saídas financeiras (compras, pagamentos, despesas)
CREATE OR ALTER VIEW VW_SaidasFinanceiras AS
    SELECT * FROM VW_ExtratoFinanceiro WHERE Tipo = 'Saida';
GO

-- 5.5. Relatório: Fluxo financeiro / saldo por período (agrupado por mês)
CREATE OR ALTER VIEW VW_FluxoFinanceiroPorPeriodo AS
    SELECT
        YEAR(DataMovimentacao) AS Ano,
        MONTH(DataMovimentacao) AS Mes,
        SUM(CASE WHEN Tipo = 'Entrada' THEN Valor ELSE 0 END) AS TotalEntradas,
        SUM(CASE WHEN Tipo = 'Saida' THEN Valor ELSE 0 END) AS TotalSaidas,
        SUM(CASE WHEN Tipo = 'Entrada' THEN Valor ELSE -Valor END) AS SaldoPeriodo
    FROM Movimentacao_Financeira
    WHERE Situacao = 'Pago'
    GROUP BY YEAR(DataMovimentacao), MONTH(DataMovimentacao);
GO



-- 6. controle de usuarios e permissoes (DCL)


IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'GerenteLogin')
    CREATE LOGIN GerenteLogin WITH PASSWORD = 'SenhaForteGerente123!';
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'GarcomLogin')
    CREATE LOGIN GarcomLogin WITH PASSWORD = 'SenhaForteGarcom123!';
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'GerenteUser')
    CREATE USER GerenteUser FOR LOGIN GerenteLogin;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'GarcomUser')
    CREATE USER GarcomUser FOR LOGIN GarcomLogin;
GO

-- gerente pode ler e escrever nas tabelas principais
GRANT SELECT, INSERT, UPDATE ON Produtos_Estoque TO GerenteUser;
GRANT SELECT, INSERT ON Movimentacao_Estoque TO GerenteUser;
GRANT SELECT, INSERT, UPDATE ON Movimentacao_Financeira TO GerenteUser;

-- garçom só consulta produtos e registra estoque
GRANT SELECT ON Produtos_Estoque TO GarcomUser;
GRANT SELECT, INSERT ON Movimentacao_Estoque TO GarcomUser;
GO



-- 7. rotina de bacukp

BACKUP DATABASE SistemaRestaurante
TO DISK = 'C:\Backup\SistemaRestaurante_Completo.bak'
WITH FORMAT,
     MEDIANAME = 'SQLServerBackups',
     NAME = 'Backup Completo - SistemaRestaurante';
GO


-- =====================================================================
-- como usar os relatorios (exemplos)
-- =====================================================================
-- SELECT * FROM VW_EstoqueAtual;
-- SELECT * FROM VW_MovimentacaoEstoque ORDER BY DataMovimentacao DESC;
-- SELECT * FROM VW_EntradasFinanceiras;
-- SELECT * FROM VW_SaidasFinanceiras;
-- SELECT * FROM VW_FluxoFinanceiroPorPeriodo ORDER BY Ano, Mes;
