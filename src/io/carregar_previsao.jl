using Dates
using DuckDB

struct PrevisaoSemanal
    categoria::String
    semana::Date
    regressao_previsto::Float64
    regressao_inferior::Float64
    regressao_superior::Float64
    arima_previsto::Float64
    arima_inferior::Float64
    arima_superior::Float64
end

function carregar_previsao(caminho)
    isfile(caminho) || throw(ArgumentError("Arquivo de previsao nao encontrado: $(caminho)"))

    csv_path = replace(replace(abspath(caminho), '\\' => '/'), "'" => "''")
    connection = DuckDB.DBInterface.connect(DuckDB.DB, ":memory:")

    try
        result = DuckDB.DBInterface.execute(
            connection,
            """
            SELECT
                CAST(categoria AS VARCHAR) AS categoria,
                CAST(item AS VARCHAR) AS item,
                CAST(semana AS DATE) AS semana,
                CAST(regressao_previsto AS DOUBLE) AS regressao_previsto,
                CAST(regressao_inferior AS DOUBLE) AS regressao_inferior,
                CAST(regressao_superior AS DOUBLE) AS regressao_superior,
                CAST(arima_previsto AS DOUBLE) AS arima_previsto,
                CAST(arima_inferior AS DOUBLE) AS arima_inferior,
                CAST(arima_superior AS DOUBLE) AS arima_superior
            FROM read_csv_auto('$(csv_path)')
            ORDER BY item, semana
            """,
        )

        previsoes = Dict{String, Vector{PrevisaoSemanal}}()
        for (linha, row) in enumerate(result)
            any(ismissing, (
                row.categoria,
                row.item,
                row.semana,
                row.regressao_previsto,
                row.regressao_inferior,
                row.regressao_superior,
                row.arima_previsto,
                row.arima_inferior,
                row.arima_superior,
            )) && throw(ArgumentError("Valor ausente na linha $(linha + 1) do arquivo $(caminho)"))

            previsao = PrevisaoSemanal(
                row.categoria,
                row.semana,
                row.regressao_previsto,
                row.regressao_inferior,
                row.regressao_superior,
                row.arima_previsto,
                row.arima_inferior,
                row.arima_superior,
            )
            push!(get!(previsoes, row.item, PrevisaoSemanal[]), previsao)
        end

        return previsoes
    finally
        DuckDB.DBInterface.close!(connection)
    end
end
