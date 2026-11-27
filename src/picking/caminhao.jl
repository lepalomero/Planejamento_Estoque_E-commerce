struct caminhao
    capacidade_volume::Int
    capacidade_quantidade::Int
    rota_produtos::Vector{Int}
    lista_produtos::Vector{String}
end

function caminhao(config::ConfigEstoque)
    capacidade_volume = config.capacidade_volume_caminhao
    capacidade_quantidade = config.capacidade_quantidade_caminhao
    if capacidade_volume === nothing || capacidade_quantidade === nothing
        throw(ArgumentError(
            "Configure capacidade_volume_caminhao e capacidade_quantidade_caminhao",
        ))
    end
    return caminhao(capacidade_volume, capacidade_quantidade, Int[], String[])
end

using Dates

function agrupar_por_dia_categoria(previsao_pedidos, informacoes_produto)
    # id -> informações do produto (busca direta, sem varrer a lista)
    info_por_id = Dict(String(p.id) => p for p in informacoes_produto)

    # dia -> categoria -> lista de produtos
    por_dia = Dict{Date, Dict{String, Vector{NamedTuple}}}()

    for p in previsao_pedidos
        info = get(info_por_id, String(p.id), nothing)
        quantidade == 0 && continue

        volume_unitario = info.altura * info.largura * info.espessura

        produto = (id              = String(p.id),
                   quantidade      = quantidade,
                   volume_unitario = volume_unitario,
                   volume_total    = quantidade * volume_unitario,
                   peso_total      = quantidade * info.peso)

        dia       = Date(p.semana)
        categoria = String(p.categoria)

        categorias = get!(por_dia, dia) do
            Dict{String, Vector{NamedTuple}}()
        end
        push!(get!(categorias, categoria, NamedTuple[]), produto) 
    end

    return por_dia
end


function alocar_caminhao(armazem, previsao_pedidos::Vector,
                         informacoes_produto, modelo::caminhao)

    por_dia = agrupar_por_dia_categoria(previsao_pedidos, informacoes_produto)
    cap_vol = modelo.capacidade_volume
    cap_qtd = modelo.capacidade_quantidade

    caminhoes_por_dia = Dict{Date, Vector{caminhao}}()

    for dia in sort(collect(keys(por_dia)))
        frota     = caminhao[]
        vol_usado = Float64[]

        novo_caminhao!() = (push!(frota, caminhao(cap_vol, cap_qtd, Int[], String[]));
                            push!(vol_usado, 0.0))
        novo_caminhao!()

        categorias = por_dia[dia]
        for categoria in sort(collect(keys(categorias)))
            produtos = sort(categorias[categoria], by = p -> p.volume_unitario, rev = true)

            for p in produtos
                if p.volume_unitario > cap_vol
                    @warn "Produto $(p.id) maior que o caminhão, ignorado" dia
                    continue
                end

                restante = p.quantidade
                while restante > 0
                    t = length(frota)
                    livre_qtd = cap_qtd - length(frota[t].lista_produtos)
                    livre_vol = cap_vol - vol_usado[t]
                    cabem = min(restante, livre_qtd,
                                floor(Int, livre_vol / p.volume_unitario))

                    if cabem == 0
                        novo_caminhao!()
                        continue
                    end

                    append!(frota[t].lista_produtos, fill(p.id, cabem))
                    vol_usado[t] += cabem * p.volume_unitario
                    restante     -= cabem
                end
            end
        end

        # descarta caminhão vazio (ex.: dia em que todos os produtos foram ignorados)
        filter!(c -> !isempty(c.lista_produtos), frota)
        isempty(frota) || (caminhoes_por_dia[dia] = frota)
    end

    # visão plana: um item por caminhão, na ordem dos dias
    produtos_por_caminhao = Vector{Vector{String}}()
    for dia in sort(collect(keys(caminhoes_por_dia)))
        for c in caminhoes_por_dia[dia]
            push!(produtos_por_caminhao, c.lista_produtos)
        end
    end

    n_caminhoes = length(produtos_por_caminhao)
    return n_caminhoes, produtos_por_caminhao, caminhoes_por_dia
end

function alocar_caminhao(armazem, previsao_pedidos::Vector, informacoes_produto, config::ConfigEstoque)
    return alocar_caminhao(
        armazem,
        previsao_pedidos,
        informacoes_produto,
        caminhao(config),
    )
end

