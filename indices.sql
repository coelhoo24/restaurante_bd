
-- Pré-requisito: as tabelas já devem existir (executar create.sql antes)
-- Ordem de execução: create.sql -> indices.sql -> insert.sql -> triggers.sql -> procedures.sql -> views.sql

-- Índice na coluna Login (tabela USUARIOS)
-- Motivo: usado toda vez que um usuário faz login no sistema
CREATE INDEX IX_Usuarios_Login ON USUARIOS(Login);

-- Índice na coluna Nome (tabela PRODUTOS_ESTOQUE)
-- Motivo: usado em buscas e filtros de produtos no cadastro/consulta
CREATE INDEX IX_Produtos_Nome ON PRODUTOS_ESTOQUE(Nome);

-- Índice na coluna DataMovimentacao (tabela MOVIMENTACAO_ESTOQUE)
-- Motivo: usado nos relatórios de movimentação de estoque por período
CREATE INDEX IX_MovEstoque_Data ON MOVIMENTACAO_ESTOQUE(DataMovimentacao);

-- Índice na coluna DataMovimentacao (tabela MOVIMENTACAO_FINANCEIRA)
-- Motivo: usado nos relatórios financeiros (entradas, saídas, fluxo por período)
CREATE INDEX IX_MovFinanceira_Data ON MOVIMENTACAO_FINANCEIRA(DataMovimentacao);
