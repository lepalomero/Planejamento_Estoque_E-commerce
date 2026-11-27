function rota_picking(warehouse::Warehouse, estantes_visitadas)
    saida = warehouse.estantes[1]
    pendentes = sort!(unique!(collect(estantes_visitadas)))
    rota = Int[0]
    distancia_total = 0.0
    atual = saida

    while !isempty(pendentes)
        sort!(pendentes; by=indice -> (
            distancia_estantes(
                atual,
                warehouse.estantes[indice + 1],
                warehouse.config.largura_armazem,
                warehouse.config.comprimento_armazem,
            ),
            indice,
        ))
        proximo = popfirst!(pendentes)
        destino = warehouse.estantes[proximo + 1]
        distancia_total += distancia_estantes(
            atual,
            destino,
            warehouse.config.largura_armazem,
            warehouse.config.comprimento_armazem,
        )
        push!(rota, proximo)
        atual = destino
    end

    if length(rota) > 1
        distancia_total += distancia_estantes(
            atual,
            saida,
            warehouse.config.largura_armazem,
            warehouse.config.comprimento_armazem,
        )
        push!(rota, 0)
    end

    return rota, Float64(distancia_total)
end
