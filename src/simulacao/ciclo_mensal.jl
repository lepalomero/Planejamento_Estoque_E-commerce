using Dates

function retirar_dia!(warehouse, mes, dia)
    # TODO: implementar retirada diária
end

function executar_ciclo!(warehouse::Warehouse, previsao, config::ConfigEstoque)
    demanda_mensal = Dict{Date,Dict{String,Float64}}()
    coluna = config.coluna_previsao

    for (item, semanas) in previsao
        for semana in semanas
            demanda = getproperty(semana, coluna)
            isfinite(demanda) && demanda >= 0 ||
                throw(ArgumentError("Previsao invalida para o item $(item)"))
            mes = Date(year(semana.semana), month(semana.semana), 1)
            por_item = get!(demanda_mensal, mes, Dict{String,Float64}())
            por_item[item] = get(por_item, item, 0.0) + demanda
        end
    end

    ordem_classe = Dict(:A => 1, :B => 2, :C => 3)
    for mes in sort!(collect(keys(demanda_mensal)))
        demandas = demanda_mensal[mes]
        itens_mes = [
            ProdutoEstoque(
                item,
                0,
                get(warehouse.volumes, item, nothing),
                get(warehouse.frequencias_pedidos, item, 0),
            ) for item in keys(demandas)
        ]
        classes = _classes_abc(itens_mes, config.abc_percentuais)
        sort!(
            itens_mes;
            by=item -> (
                ordem_classe[classes[item.id]],
                -item.frequencia_pedidos,
                item.id,
            ),
        )

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
                alocar!(warehouse, [reposicao], MetodoABC())
            catch erro
                erro isa ArgumentError || rethrow()
                @warn "Reposicao nao coube no Warehouse" mes=mes item=item.id erro=erro
            end
        end

        # adicionar a alocação aqui !!!!!!!!!!!
        for dia in 1:day(lastdayofmonth(mes))
            retirar_dia!(warehouse, mes, dia)
        end
    end
    return warehouse
end
