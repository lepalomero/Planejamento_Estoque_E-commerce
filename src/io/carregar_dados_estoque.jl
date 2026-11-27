function carregar_dados_estoque(caminho_pedidos, caminho_produtos)
    isfile(caminho_pedidos) ||
        throw(ArgumentError("Arquivo de pedidos nao encontrado: $(caminho_pedidos)"))
    isfile(caminho_produtos) ||
        throw(ArgumentError("Arquivo de produtos nao encontrado: $(caminho_produtos)"))

    pedidos_path = sql_path(caminho_pedidos)
    produtos_path = sql_path(caminho_produtos)
    connection = DuckDB.DBInterface.connect(DuckDB.DB, ":memory:")
    try
        pedidos_result = DuckDB.DBInterface.execute(
            connection,
            """
            SELECT data_do_pedido, ids_dos_produtos
            FROM read_csv_auto('$(pedidos_path)')
            """,
        )
        produtos_result = DuckDB.DBInterface.execute(
            connection,
            """
            SELECT id, categoria, altura, largura, espessura
            FROM read_csv_auto('$(produtos_path)')
            """,
        )

        pedidos = [
            (
                data_do_pedido=row.data_do_pedido,
                ids_dos_produtos=row.ids_dos_produtos,
            ) for row in pedidos_result
        ]
        produtos = [
            (
                id=row.id,
                categoria=row.categoria,
                altura=row.altura,
                largura=row.largura,
                espessura=row.espessura,
            ) for row in produtos_result
        ]
        return pedidos, produtos
    finally
        DuckDB.DBInterface.close!(connection)
    end
end
