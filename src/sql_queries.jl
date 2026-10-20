using DuckDB

const CSV_FILES = (
    "olist_customers_dataset.csv",
    "olist_order_items_dataset.csv",
    "olist_orders_dataset.csv",
    "olist_products_dataset.csv",
)

sql_path(path) = replace(replace(abspath(path), '\\' => '/'), "'" => "''")

function register_csv(connection, archive_dir, filename, table_name)
    csv_path = sql_path(joinpath(archive_dir, filename))
    DuckDB.DBInterface.execute(
        connection,
        "CREATE VIEW $(table_name) AS SELECT * FROM read_csv_auto('$(csv_path)')",
    )
end

function run_queries()
    project_dir = dirname(@__DIR__)
    archive_dir = joinpath(project_dir, "archive")
    output_dir = joinpath(project_dir, "outputs")
    mkpath(output_dir)

    missing_files = filter(name -> !isfile(joinpath(archive_dir, name)), CSV_FILES)
    isempty(missing_files) || error(
        "Arquivos CSV não encontrados em $(archive_dir): $(join(missing_files, ", "))",
    )

    connection = DuckDB.DBInterface.connect(DuckDB.DB, ":memory:")
    try
        register_csv(connection, archive_dir, "olist_customers_dataset.csv", "olist_customers_dataset")
        register_csv(connection, archive_dir, "olist_order_items_dataset.csv", "olist_order_items_dataset")
        register_csv(connection, archive_dir, "olist_orders_dataset.csv", "olist_orders_dataset")
        register_csv(connection, archive_dir, "olist_products_dataset.csv", "olist_products_dataset")

        DuckDB.DBInterface.execute(
            connection,
            """
            CREATE TEMP TABLE categorias_itens AS
            SELECT
                p.product_category_name AS categoria,
                COUNT(*) AS itens
            FROM olist_order_items_dataset AS i
            JOIN olist_products_dataset AS p USING (product_id)
            GROUP BY p.product_category_name
            """,
        )

        DuckDB.DBInterface.execute(
            connection,
            """
            CREATE TEMP TABLE categorias_80pct AS
            WITH ranked AS (
                SELECT
                    categoria,
                    itens,
                    SUM(itens) OVER (ORDER BY itens DESC, categoria) AS itens_acumulados,
                    SUM(itens) OVER () AS total_itens
                FROM categorias_itens
            ),
            corte AS (
                SELECT MIN(itens_acumulados) AS limite_acumulado
                FROM ranked
                WHERE itens_acumulados >= total_itens * 0.8
            )
            SELECT r.categoria
            FROM ranked AS r
            CROSS JOIN corte AS c
            WHERE r.itens_acumulados <= c.limite_acumulado
            ORDER BY r.itens DESC, r.categoria
            """,
        )

        DuckDB.DBInterface.execute(
            connection,
            """
            CREATE TEMP TABLE produtos_filtrados AS
            SELECT
                p.product_id AS id,
                p.product_category_name AS categoria,
                p.product_weight_g AS peso,
                p.product_height_cm AS altura,
                p.product_width_cm AS largura,
                p.product_length_cm AS espessura,
                COALESCE(AVG(i.price), 0.0) AS valor_do_produto
            FROM olist_products_dataset AS p
            JOIN categorias_80pct AS c ON c.categoria = p.product_category_name
            LEFT JOIN olist_order_items_dataset AS i USING (product_id)
            GROUP BY
                p.product_id,
                p.product_category_name,
                p.product_weight_g,
                p.product_height_cm,
                p.product_width_cm,
                p.product_length_cm
            """,
        )

        DuckDB.DBInterface.execute(
            connection,
            """
            CREATE TEMP TABLE itens_validos AS
            SELECT
                i.order_id,
                i.product_id,
                i.price
            FROM olist_order_items_dataset AS i
            JOIN olist_products_dataset AS p USING (product_id)
            JOIN categorias_80pct AS c ON c.categoria = p.product_category_name
            """,
        )

        DuckDB.DBInterface.execute(
            connection,
            """
            CREATE TEMP TABLE pedidos_validos AS
            WITH ids_produtos AS (
                SELECT
                    order_id,
                    STRING_AGG(product_id, ';' ORDER BY product_id) AS ids_dos_produtos
                FROM itens_validos
                GROUP BY order_id
            ),
            valores_pedidos AS (
                SELECT
                    order_id,
                    SUM(price) AS valor_do_pedido
                FROM itens_validos
                GROUP BY order_id
            )
            SELECT
                o.order_id AS id,
                vp.valor_do_pedido,
                CAST(o.order_purchase_timestamp AS TIMESTAMP) AS data_do_pedido,
                ip.ids_dos_produtos,
                c.customer_zip_code_prefix AS zipcode,
                c.customer_city AS cidade,
                c.customer_state AS estado
            FROM olist_orders_dataset AS o
            JOIN ids_produtos AS ip USING (order_id)
            JOIN valores_pedidos AS vp USING (order_id)
            LEFT JOIN olist_customers_dataset AS c USING (customer_id)
            ORDER BY o.order_id
            """,
        )

        pedidos_path = sql_path(joinpath(output_dir, "pedidos.csv"))
        produtos_path = sql_path(joinpath(output_dir, "produtos.csv"))

        DuckDB.DBInterface.execute(
            connection,
            """
            COPY (
                SELECT
                    id,
                    valor_do_pedido,
                    data_do_pedido,
                    ids_dos_produtos,
                    zipcode,
                    cidade,
                    estado
                FROM pedidos_validos
            )
            TO '$(pedidos_path)' (HEADER, DELIMITER ',')
            """,
        )

        DuckDB.DBInterface.execute(
            connection,
            """
            COPY (
                SELECT
                    id,
                    categoria,
                    peso,
                    altura,
                    largura,
                    espessura,
                    valor_do_produto
                FROM produtos_filtrados
                ORDER BY categoria, id
            )
            TO '$(produtos_path)' (HEADER, DELIMITER ',')
            """,
        )

        println("Arquivos gerados em: $(output_dir)")
        println("- pedidos.csv")
        println("- produtos.csv")
    finally
        DuckDB.DBInterface.close!(connection)
    end
end
