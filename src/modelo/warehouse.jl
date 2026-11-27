mutable struct Estante
    id::Int
    posicao::Tuple{Float64,Float64}
    itens::Vector{ItemArmazenado}
    capacidade::Float64
    eh_saida::Bool
end

mutable struct GrafoWarehouse
    adjacencias::Vector{Vector{Tuple{Int,Float64}}}
end

GrafoWarehouse() = GrafoWarehouse(Vector{Tuple{Int,Float64}}[])

mutable struct Warehouse
    grafo::GrafoWarehouse
    estantes::Vector{Estante}
    config::ConfigEstoque
    volumes::Dict{String,Union{Nothing,Float64}}
    frequencias_pedidos::Dict{String,Int}
end

function Warehouse(config::ConfigEstoque)
    capacidade = config.capacidade_prateleira * config.prateleiras_por_estante
    estantes = Estante[
        Estante(
            0,
            (Float64(config.posicao_saida[1]), Float64(config.posicao_saida[2])),
            ItemArmazenado[],
            0.0,
            true,
        ),
    ]

    por_nivel = 2 * config.largura_armazem
    niveis = cld(config.n_estantes, por_nivel)
    passo_x = (config.comprimento_armazem / 2) / niveis
    for indice in 1:config.n_estantes
        nivel = div(indice - 1, por_nivel) + 1
        posicao_nivel = mod(indice - 1, por_nivel)
        lado = iseven(posicao_nivel) ? 1.0 : -1.0
        y = div(posicao_nivel, 2)
        x = lado * (nivel - 0.5) * passo_x
        push!(
            estantes,
            Estante(
                indice,
                (Float64(x), Float64(y)),
                ItemArmazenado[],
                capacidade,
                false,
            ),
        )
    end

    return Warehouse(
        GrafoWarehouse(),
        estantes,
        config,
        Dict{String,Union{Nothing,Float64}}(),
        Dict{String,Int}(),
    )
end
