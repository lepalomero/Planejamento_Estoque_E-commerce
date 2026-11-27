using Dates

function executar_ciclo!(
    warehouse::Warehouse,
    previsao,
    config::ConfigEstoque;
    pasta_saida=nothing,
    metodo::MetodoAlocacao=MetodoABC(),
    sufixo_metodo="",
)
    demanda_semanal = Dict{Date,Dict{String,Float64}}()
    coluna = config.coluna_previsao

    for (item, semanas) in previsao
        for semana in semanas
            demanda = getproperty(semana, coluna)
            isfinite(demanda) && demanda >= 0 ||
                throw(ArgumentError("Previsao invalida para o item $(item)"))
            por_item = get!(demanda_semanal, semana.semana, Dict{String,Float64}())
            por_item[item] = get(por_item, item, 0.0) + demanda
        end
    end

    semanas_por_mes = Dict{Date,Vector{Date}}()
    demanda_mensal = Dict{Date,Dict{String,Int}}()
    for semana in sort!(collect(keys(demanda_semanal)))
        mes = Date(year(semana), month(semana), 1)
        push!(get!(semanas_por_mes, mes, Date[]), semana)
        por_item = get!(demanda_mensal, mes, Dict{String,Int}())
        for (item, demanda) in demanda_semanal[semana]
            por_item[item] = get(por_item, item, 0) + ceil(Int, demanda)
        end
    end

    pasta_saida === nothing || mkpath(pasta_saida)
    for mes in sort!(collect(keys(demanda_mensal)))
        demandas = demanda_mensal[mes]
        itens_mes = [
            ProdutoEstoque(
                item,
                demanda,
                get(warehouse.volumes, item, nothing),
                get(warehouse.frequencias_pedidos, item, 0),
            ) for (item, demanda) in demandas
        ]
        itens_mes = _itens_ordenados(itens_mes, config.abc_percentuais, metodo)

        for item in itens_mes
            demanda = demandas[item.id]
            estoque_atual = sum(
                alocado.quantidade
                for estante in warehouse.estantes
                for alocado in estante.itens
                if alocado.id == item.id;
                init=0,
            )
            deficit = ceil(Int, demanda) - estoque_atual
            deficit > 0 || continue

            reposicao = ProdutoEstoque(
                item.id,
                deficit,
                item.volume,
                item.frequencia_pedidos,
            )
            try
                alocar!(warehouse, [reposicao], metodo)
            catch erro
                erro isa ArgumentError || rethrow()
                @warn "Reposicao nao coube no Warehouse" mes=mes item=item.id erro=erro
            end
        end

        for semana in semanas_por_mes[mes]
            demandas_semana = Dict(
                item => ceil(Int, demanda)
                for (item, demanda) in demanda_semanal[semana]
            )
            executar_picking_wave!(
                warehouse,
                semana,
                demandas_semana,
                pasta_saida;
                sufixo_metodo=sufixo_metodo,
            )
        end

        if pasta_saida !== nothing
            sufixo = Dates.format(mes, dateformat"yyyy-mm")
            salvar_estoque(
                joinpath(
                    pasta_saida,
                    _sufixar_arquivo("estoque_mensal_$(sufixo).csv", sufixo_metodo),
                ),
                warehouse,
            )
        end
    end
    return warehouse
end
