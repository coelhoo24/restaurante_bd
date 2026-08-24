Mapeamento de Relacionamentos (Modelo Conceitual / DER)


Usuarios (1) ─── (N) Movimentacao_Estoque: Um usuário pode registrar várias movimentações de estoque, mas cada movimentação é registrada por apenas um usuário.

Produtos_Estoque (1) ─── (N) Movimentacao_Estoque: Um produto pode ter várias entradas e saídas ao longo do tempo.

Usuarios (1) ─── (N) Movimentacao_Financeira: Um usuário (ex: gerente ou caixa) é responsável por registrar as entradas ou saídas financeiras.

Categorias_Financeiras (1) ─── (N) Movimentacao_Financeira: Uma categoria (ex: "Vendas", "Fornecedores", "Energia") pode classificar diversos lançamentos financeiros.