USE SistemaRestaurante;
GO

-- Inserir Usuário Administrador Inicial (Senha de exemplo tratada em HASH)
INSERT INTO Usuarios (Nome, Login, SenhaHash, Nivel_Permissao)
VALUES ('Matheus Gerente', 'matheus.gerente', '8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918', 'Gerente'),
       ('Rafaella Garçom', 'rafaella.garcom', '8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918', 'Garcom');

-- Inserir Categorias Financeiras padrão
INSERT INTO Categorias_Financeiras (Nome, Tipo) VALUES 
('Venda de Pratos', 'Entrada'),
('Venda de Bebidas', 'Entrada'),
('Compra de Ingredientes', 'Saida'),
('Pagamento de Fornecedores', 'Saida'),
('Contas Operacionais', 'Saida');

-- Inserir Produtos de Exemplo
INSERT INTO Produtos_Estoque (Nome, Descricao, Quantidade_Atual, Preco_Custo, Preco_Venda) VALUES
('Refrigerante Lata 350ml', 'Lata de alumínio', 48, 2.50, 6.00),
('Carne Picanha (kg)', 'Peça resfriada', 15, 45.00, 90.00);