import Pkg
Pkg.activate(@__DIR__)
Pkg.instantiate()

using JuMP
using HiGHS
using Revise

function main()

	# Função que abre arquivo de entrada informado e retorna os valores contidos
	function getValuesFromFileInput()
		
		print("\nInforme o caminho do arquivo (.txt) (se estiver dentro da pasta 'formulation' basta digitar o nome do arquivo com a extensão): \n")  
		
		# Pega o caminho informado pelo usuário
		fileName = readline()

		try 
			# Abre arquivo de entrada
			open(fileName) do f

				# Lê o conteúdo do arquivo, onde:
		
				# Primeira linha = #bins
				if ! eof(f)
					bins = parse(Int64, readline(f))
				end

				# Segunda linha = #balls
				if ! eof(f)
					balls = parse(Int64, readline(f))
				end

				# Terceira linha em diante = limites inferiores e superiores de cada recipiente if
				i=2
				minLimits = Vector{Int64}(undef, bins)
                maxLimits = Vector{Int64}(undef, bins)

				# Inicializa o vetor
				if !eof(f) && bins > 0
                    line = readline(f)
                    limMin, limMax = split(line, " ")
					limMin = parse(Int64, limMin)
                    limMax = parse(Int64, limMax)
                    minLimits[1] = limMin
                    maxLimits[1] = limMax
				end

				while !eof(f) && i <= bins
					line = readline(f)
                    limMin, limMax = split(line, " ")
					limMin = parse(Int64, limMin)
                    limMax = parse(Int64, limMax)
                    minLimits[i] = limMin
                    maxLimits[i] = limMax
                    i += 1
				end

			end

			# Retorna os valores
			return bins, balls, minLimits, maxLimits

		catch
			# Avisa que o arquivo não existe
			println("\nERRO: Arquivo informado não existe.")

			# Reinicia o processo
			return getValuesFromFileInput()
		end
	end

	# Função que retorna o valor da semente de aleatoriedade
	function getRandomSeedInput()
		
		print("\nInforme o valor da semente de aleatoriedade (de 1 a 10): \n")  
		
		# Pega o valor informado
		seed = readline()

		# Verifica se é um número
		if tryparse(Int64, seed) !== nothing

			# Se for, converte para inteiro
			seed = parse(Int64, seed)

			# Verifica se o valor está dentro do intervalo
			if seed >= 1 && seed <= 10
				# Se estiver, retorna
				return seed
			else
				# Se não, avisa e reinicia o processo
				print("\nERRO: O valor da semente de aleatoriedade deve ser de 1 a 10.\n")  
				return getRandomSeedInput()
			end
		else
			# Se não, avisa e reinicia o processo
			print("\nERRO: O valor da semente de aleatoriedade deve ser um número inteiro.\n")  
			return getRandomSeedInput()
		end
	end

	# Função que retorna o limite de tempo de execução em segundos
	function getTimeLimitInput()
		
		print("\nInforme o limite de tempo de execução (em segundos): \n")

		# Pega o valor informado
		timeLimit = readline()

		# Verifica se é um número
		if tryparse(Float64, timeLimit) !== nothing

			# Se for, converte para real
			timeLimit = parse(Float64, timeLimit)

			# Verifica se o valor é não negativo
			if timeLimit >= 0
				# Se for, retorna
				return timeLimit
			else
				# Se não, avisa e reinicia o processo
				print("\nERRO: O limite de tempo não pode ser negativo.\n") 
				return getTimeLimitInput()
			end
		else
			# Se não, avisa e reinicia o processo
			print("\nERRO: O valor da semente de aleatoriedade deve ser um número real.\n")  
			return getTimeLimitInput()
		end
	end

	# --------------------------------------------------------

	# Cria o modelo usando HiGHS como solver
	m = Model(HiGHS.Optimizer)

	# Coleta os valores a partir de um arquivo de entrada informado pelo usuário
	bins, balls, minLimits, maxLimits = getValuesFromFileInput()

	# print("\nnº de recipientes (bins): $bins, nº de bolas (balls): = $balls\n")
	# print("$limits\n")

	# Define a semente de aleatoriedade
	set_attribute(m, "random_seed", getRandomSeedInput())

	# Define o limite de tempo
	set_time_limit_sec(m, getTimeLimitInput())

    # Variáveis ----------------------------------------------

    # s(i,k) indica se o recipiente i tem pelo menos k bolas
    @variable(m, s[1:bins, 1:maximum(maxLimits)], Bin)

	# Função Objetivo ----------------------------------------

    # Máxima soma dos lucros dos recipientes
	@objective(m, Max, sum(s[i, k]*k for i in 1:bins, k in 1:maxLimits[i]))

	# Restrições ---------------------------------------------

	# A quantidade de bolas em cada recipiente i não pode ser menor que o lower bound do mesmo
	@constraint(m, [i=1:bins], sum(s[i, k] for k in 1:maxLimits[i]) >= minLimits[i])

	# A quantidade de bolas em cada recipiente i não pode ser maior que o upper bound do mesmo
	@constraint(m, [i=1:bins], sum(s[i, k] for k in 1:maxLimits[i]) <= maxLimits[i])

	# A soma total das bolas nos recipientes deve ser igual ao número total de bolas.
	# Não pode ser maior pois estaríamos utilizando mais bolas do que temos.
	# Não pode ser menor pois não pode restar nenhuma bola fora dos recipientes.
	@constraint(m, sum(s[i, k] for i in 1:bins, k in 1:maxLimits[i]) == balls)

	# Garantir que só teremos pelo menos k bolas em um recipiente i se tivermos pelo menos k-1 bolas nele
	# Dessa forma, impedimos casos como, por exemplo: s[i,10] = 1 e s[i,9] = 0 -> recipiente i tem pelo menos 10 bolas, mas não tem pelo menos 9 bolas (?)
	@constraint(m, [i=1:bins, k in 2:maxLimits[i]], s[i,k] <= s[i,k-1])

	# --------------------------------------------------------

	# Resolve o modelo
	optimize!(m)

	# # Mostra a quantidade de bolas por recipiente
	# for i in 1:bins
	# 	for k in 1:maxLimits[i]
	# 		if(k != maxLimits[i])
	# 			if(value(s[i,k]) == 1.0 && value(s[i,k+1]) == 0.0)
	# 				print("Recipiente $i, $k bolas\n")
	# 			end
	# 		else
	# 			if(value(s[i,k]) == 1.0)
	# 				print("Recipiente $i, $k bolas\n")
	# 			end
	# 		end
	# 	end
	# end

	# Mostra o valor da função objetivo
	@show objective_value(m)

end

main()

