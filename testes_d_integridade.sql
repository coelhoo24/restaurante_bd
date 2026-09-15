
-- Teste d integridade - SistemaRestaurante
--não cria nada novo no banco - ele só testa se as regras
-- que já estao nas tabelas (PK, FK, CHECK, UNIQUE) e nos objetos
-- (trigger e procedure) estão funcionando mesmo. a ideia é
-- provocar erros de propósito (ex: tentar inserir um login duplicado)
-- e confirmar que o banco realmente bloqueia, em vez de aceitar
-- qualquer coisa.
--

USE SistemaRestaurante;
GO

PRINT '=====================================================';
PRINT 'TESTE 1: CHECK constraint - Nivel_Permissao inválido';
PRINT '=====================================================';
BEGIN TRY
    INSERT INTO Usuarios (Nome, Login, SenhaHash, Nivel_Permissao)
    VALUES ('Teste Invalido', 'teste.invalido', 'hashfake', 'Cozinheiro'); -- não existe na lista permitida
    PRINT 'FALHOU (o insert deveria ter sido bloqueado, mas passou)';
END TRY
BEGIN CATCH
    PRINT 'OK - o banco bloqueou corretamente: ' + ERROR_MESSAGE();
END CATCH
GO

PRINT '';
PRINT '=====================================================';
PRINT 'TESTE 2: CHECK constraint - Quantidade <= 0';
PRINT '=====================================================';
BEGIN TRY
    -- usa o Produto_ID = 1 e Usuario_ID = 1 (ajusta se os seus IDs forem diferentes)
    INSERT INTO Movimentacao_Estoque (Produto_ID, Usuario_ID, Tipo_Movimentacao, Quantidade, Observacao)
    VALUES (1, 1, 'Entrada', -5, 'Quantidade negativa - deve falhar');
    PRINT 'FALHOU (o insert deveria ter sido bloqueado, mas passou)';
END TRY
BEGIN CATCH
    PRINT 'OK - o banco bloqueou corretamente: ' + ERROR_MESSAGE();
END CATCH
GO

PRINT '';
PRINT '=====================================================';
PRINT 'TESTE 3: FK inválida - Produto_ID inexistente';
PRINT '=====================================================';
BEGIN TRY
    INSERT INTO Movimentacao_Estoque (Produto_ID, Usuario_ID, Tipo_Movimentacao, Quantidade, Observacao)
    VALUES (9999, 1, 'Entrada', 10, 'Produto que não existe - deve falhar');
    PRINT 'FALHOU (o insert deveria ter sido bloqueado, mas passou)';
END TRY
BEGIN CATCH
    PRINT 'OK - o banco bloqueou corretamente: ' + ERROR_MESSAGE();
END CATCH
GO

PRINT '';
PRINT '=====================================================';
PRINT 'TESTE 4: UNIQUE constraint - Login duplicado';
PRINT '=====================================================';
BEGIN TRY
    INSERT INTO Usuarios (Nome, Login, SenhaHash, Nivel_Permissao)
    VALUES ('Outro Matheus', 'matheus.gerente', 'hashfake', 'Caixa'); -- login já existe
    PRINT 'FALHOU (o insert deveria ter sido bloqueado, mas passou)';
END TRY
BEGIN CATCH
    PRINT 'OK - o banco bloqueou corretamente: ' + ERROR_MESSAGE();
END CATCH
GO

PRINT '';
PRINT '=====================================================';
PRINT 'TESTE 5: Trigger TRG_AtualizaEstoque - Entrada';
PRINT '=====================================================';
DECLARE @QtdAntes INT, @QtdDepois INT;

SELECT @QtdAntes = Quantidade_Atual FROM Produtos_Estoque WHERE ID = 1;

INSERT INTO Movimentacao_Estoque (Produto_ID, Usuario_ID, Tipo_Movimentacao, Quantidade, Observacao)
VALUES (1, 1, 'Entrada', 10, 'Teste automático de entrada');

SELECT @QtdDepois = Quantidade_Atual FROM Produtos_Estoque WHERE ID = 1;

IF @QtdDepois = @QtdAntes + 10
    PRINT 'OK - estoque foi de ' + CAST(@QtdAntes AS VARCHAR) + ' para ' + CAST(@QtdDepois AS VARCHAR);
ELSE
    PRINT 'FALHOU - esperava ' + CAST(@QtdAntes + 10 AS VARCHAR) + ' mas ficou ' + CAST(@QtdDepois AS VARCHAR);
GO

PRINT '';
PRINT '=====================================================';
PRINT 'TESTE 6: Trigger TRG_AtualizaEstoque - Saida';
PRINT '=====================================================';
DECLARE @QtdAntes INT, @QtdDepois INT;

SELECT @QtdAntes = Quantidade_Atual FROM Produtos_Estoque WHERE ID = 1;

INSERT INTO Movimentacao_Estoque (Produto_ID, Usuario_ID, Tipo_Movimentacao, Quantidade, Observacao)
VALUES (1, 1, 'Saida', 4, 'Teste automático de saída');

SELECT @QtdDepois = Quantidade_Atual FROM Produtos_Estoque WHERE ID = 1;

IF @QtdDepois = @QtdAntes - 4
    PRINT 'OK - estoque foi de ' + CAST(@QtdAntes AS VARCHAR) + ' para ' + CAST(@QtdDepois AS VARCHAR);
ELSE
    PRINT 'FALHOU - esperava ' + CAST(@QtdAntes - 4 AS VARCHAR) + ' mas ficou ' + CAST(@QtdDepois AS VARCHAR);
GO

PRINT '';
PRINT '=====================================================';
PRINT 'TESTE 7: Procedure SP_RegistrarMovimentacaoEstoque - caso válido';
PRINT '=====================================================';
DECLARE @QtdAntes INT, @QtdDepois INT;

SELECT @QtdAntes = Quantidade_Atual FROM Produtos_Estoque WHERE ID = 2;

EXEC SP_RegistrarMovimentacaoEstoque
    @Produto_ID = 2,
    @Usuario_ID = 1,
    @Tipo_Movimentacao = 'Entrada',
    @Quantidade = 3,
    @Observacao = 'Teste via procedure';

SELECT @QtdDepois = Quantidade_Atual FROM Produtos_Estoque WHERE ID = 2;

IF @QtdDepois = @QtdAntes + 3
    PRINT 'OK - procedure executou e a trigger atualizou o estoque corretamente';
ELSE
    PRINT 'FALHOU - estoque não foi atualizado como esperado';
GO

PRINT '';
PRINT '=====================================================';
PRINT 'TESTE 8: Procedure SP_RegistrarMovimentacaoEstoque - deve dar ROLLBACK';
PRINT '=====================================================';
DECLARE @QtdAntes INT, @QtdDepois INT, @TotalAntes INT, @TotalDepois INT;

SELECT @TotalAntes = COUNT(*) FROM Movimentacao_Estoque;

BEGIN TRY
    -- Produto_ID inexistente força a FK a rejeitar dentro da procedure
    EXEC SP_RegistrarMovimentacaoEstoque
        @Produto_ID = 9999,
        @Usuario_ID = 1,
        @Tipo_Movimentacao = 'Entrada',
        @Quantidade = 1,
        @Observacao = 'Deve falhar e dar rollback';
    PRINT 'FALHOU (deveria ter lançado erro, mas não lançou)';
END TRY
BEGIN CATCH
    PRINT 'OK - a procedure capturou o erro e chamou ROLLBACK: ' + ERROR_MESSAGE();
END CATCH

SELECT @TotalDepois = COUNT(*) FROM Movimentacao_Estoque;

IF @TotalAntes = @TotalDepois
    PRINT 'OK - nenhuma linha foi inserida (rollback funcionou de verdade)';
ELSE
    PRINT 'FALHOU - o número de movimentações mudou mesmo com erro';
GO

PRINT '';
PRINT '=====================================================';
PRINT 'TESTE 9: View VW_ExtratoFinanceiro - retorna dados';
PRINT '=====================================================';
IF EXISTS (SELECT 1 FROM VW_ExtratoFinanceiro)
BEGIN
    PRINT 'OK - a view retornou dados:';
    SELECT * FROM VW_ExtratoFinanceiro;
END
ELSE
    PRINT 'ATENÇÃO - a view não retornou nenhuma linha (normal se ainda não há Movimentacao_Financeira cadastrada)';
GO

PRINT '';
PRINT '=====================================================';
PRINT 'TESTE 10: Trigger deve bloquear saída maior que o estoque';
PRINT '=====================================================';
DECLARE @QtdAntes INT, @QtdDepois INT, @TotalAntes INT, @TotalDepois INT;

SELECT @QtdAntes = Quantidade_Atual FROM Produtos_Estoque WHERE ID = 1;
SELECT @TotalAntes = COUNT(*) FROM Movimentacao_Estoque;

BEGIN TRY
    -- Pede uma saída maior do que o produto tem em estoque - deve ser bloqueada
    INSERT INTO Movimentacao_Estoque (Produto_ID, Usuario_ID, Tipo_Movimentacao, Quantidade, Observacao)
    VALUES (1, 1, 'Saida', @QtdAntes + 1000, 'Saída maior que o estoque - deve falhar');
    PRINT 'FALHOU (deveria ter sido bloqueado, mas passou)';
END TRY
BEGIN CATCH
    PRINT 'OK - a trigger bloqueou a saída: ' + ERROR_MESSAGE();
END CATCH

SELECT @QtdDepois = Quantidade_Atual FROM Produtos_Estoque WHERE ID = 1;
SELECT @TotalDepois = COUNT(*) FROM Movimentacao_Estoque;

IF @QtdAntes = @QtdDepois AND @TotalAntes = @TotalDepois
    PRINT 'OK - nem o estoque nem o total de movimentações mudaram (rollback completo)';
ELSE
    PRINT 'FALHOU - algo foi alterado mesmo com o bloqueio';
GO

PRINT '';
PRINT '=====================================================';
PRINT 'TESTE 11: Procedure SP_RegistrarMovimentacaoFinanceira - caso válido';
PRINT '=====================================================';
DECLARE @IdCategoriaEntrada INT, @TotalAntes INT, @TotalDepois INT;

-- Pega a primeira categoria cadastrada do tipo 'Entrada'
SELECT TOP 1 @IdCategoriaEntrada = ID FROM Categorias_Financeiras WHERE Tipo = 'Entrada';

SELECT @TotalAntes = COUNT(*) FROM Movimentacao_Financeira;

EXEC SP_RegistrarMovimentacaoFinanceira
    @Usuario_ID = 1,
    @Categoria_ID = @IdCategoriaEntrada,
    @Tipo = 'Entrada',
    @Descricao = 'Teste automático de entrada financeira',
    @Valor = 50.00;

SELECT @TotalDepois = COUNT(*) FROM Movimentacao_Financeira;

IF @TotalDepois = @TotalAntes + 1
    PRINT 'OK - a movimentação financeira foi registrada';
ELSE
    PRINT 'FALHOU - a movimentação não foi inserida';
GO

PRINT '';
PRINT '=====================================================';
PRINT 'TESTE 12: Procedure deve bloquear Tipo incompatível com a Categoria';
PRINT '=====================================================';
DECLARE @IdCategoriaEntrada INT, @TotalAntes INT, @TotalDepois INT;

-- Pegar uma categoria de 'Entrada', mas tentar registrar como 'Saida'
SELECT TOP 1 @IdCategoriaEntrada = ID FROM Categorias_Financeiras WHERE Tipo = 'Entrada';

SELECT @TotalAntes = COUNT(*) FROM Movimentacao_Financeira;

BEGIN TRY
    EXEC SP_RegistrarMovimentacaoFinanceira
        @Usuario_ID = 1,
        @Categoria_ID = @IdCategoriaEntrada,
        @Tipo = 'Saida', -- incompatível com a categoria escolhida - deve falhar
        @Descricao = 'Teste de incompatibilidade categoria x tipo',
        @Valor = 20.00;
    PRINT 'FALHOU (deveria ter sido bloqueado, mas passou)';
END TRY
BEGIN CATCH
    PRINT 'OK - a procedure bloqueou corretamente: ' + ERROR_MESSAGE();
END CATCH

SELECT @TotalDepois = COUNT(*) FROM Movimentacao_Financeira;

IF @TotalAntes = @TotalDepois
    PRINT 'OK - nenhuma linha foi inserida';
ELSE
    PRINT 'FALHOU - uma linha foi inserida mesmo com o tipo incompatível';
GO

PRINT '';
PRINT '=====================================================';
PRINT 'TESTE 13: View VW_EstoqueAtual (Relatório 1)';
PRINT '=====================================================';
IF EXISTS (SELECT 1 FROM VW_EstoqueAtual)
BEGIN
    PRINT 'OK - a view retornou dados:';
    SELECT * FROM VW_EstoqueAtual;
END
ELSE
    PRINT 'ATENÇÃO - a view não retornou nenhuma linha';
GO

PRINT '';
PRINT '=====================================================';
PRINT 'TESTE 14: View VW_MovimentacaoEstoque (Relatório 2)';
PRINT '=====================================================';
IF EXISTS (SELECT 1 FROM VW_MovimentacaoEstoque)
BEGIN
    PRINT 'OK - a view retornou dados:';
    SELECT * FROM VW_MovimentacaoEstoque ORDER BY DataMovimentacao DESC;
END
ELSE
    PRINT 'ATENÇÃO - a view não retornou nenhuma linha';
GO

PRINT '';
PRINT '=====================================================';
PRINT 'TESTE 15: Views VW_EntradasFinanceiras e VW_SaidasFinanceiras (Relatórios 3 e 4)';
PRINT '=====================================================';
IF EXISTS (SELECT 1 FROM VW_EntradasFinanceiras)
    PRINT 'OK - VW_EntradasFinanceiras retornou dados';
ELSE
    PRINT 'ATENÇÃO - VW_EntradasFinanceiras não retornou nenhuma linha';

IF EXISTS (SELECT 1 FROM VW_SaidasFinanceiras)
    PRINT 'OK - VW_SaidasFinanceiras retornou dados';
ELSE
    PRINT 'ATENÇÃO - VW_SaidasFinanceiras não retornou nenhuma linha (normal se ainda não há saída cadastrada)';

SELECT * FROM VW_EntradasFinanceiras;
SELECT * FROM VW_SaidasFinanceiras;
GO

PRINT '';
PRINT '=====================================================';
PRINT 'TESTE 16: View VW_FluxoFinanceiroPorPeriodo (Relatório 5)';
PRINT '=====================================================';
IF EXISTS (SELECT 1 FROM VW_FluxoFinanceiroPorPeriodo)
BEGIN
    PRINT 'OK - a view retornou dados:';
    SELECT * FROM VW_FluxoFinanceiroPorPeriodo ORDER BY Ano, Mes;
END
ELSE
    PRINT 'ATENÇÃO - a view não retornou nenhuma linha';
GO

PRINT '';
PRINT '=====================================================';
PRINT 'RESUMO: revise as linhas "OK" e "FALHOU" acima';
PRINT '=====================================================';
