class Array
	def sum
		sum = 0; each {|c| sum += yield(c)}
		sum
	end
end

class EvolutionSim
	def initialize(populationSize, generationLength, initialPopulation = nil)
		@populationSize = populationSize
		@generationLength = generationLength
		@chromosomes = []
		if initialPopulation
			initialPopulation.each {|p| @chromosomes << Chromosome.new(p)}
		else
			@chromosomes = generateData
		end
	end

	def generateData
		list = []
		@populationSize.times do
			list << Chromosome.new
		end
		list
	end

	def run(debug = false, breakWhenDone = true, interval = 4)
		@generationLength.times do |i|
			Chromosome.rankAndSort(@chromosomes)
			if i % interval == 0 && debug
				percent = ((i.to_f / @generationLength.to_f) * 100).round
				best = @chromosomes[0]
				worst = @chromosomes[-1]
				begin
					printf "\r" + yield(percent, best, worst).to_s
				rescue
					printf "\r#{percent}%% | #{best}"
					printf " | #{best.fitness.round}                            "
				end
			end
		  replaceWorstRanked(getOffsprings(selection))
		  break if @chromosomes[0].fitness == 100 && breakWhenDone
		end
		Chromosome.rankAndSort(@chromosomes)
		@chromosomes[0]
	end

	def selection
		sum = @chromosomes.sum {|c| c.normalizedFitness}
		selected = []
		(@chromosomes.length * (1.0 / 3.0)).to_i.times do
			r = Random.rand(0...sum)
			for i in 0...(@chromosomes.length)
				t = @chromosomes[0..i].sum {|c| c.normalizedFitness}
				if t > r
					selected << @chromosomes[i]
					break
				end
			end
		end
		selected
	end

	def getOffsprings(selected)
		offsprings = []
		i = 0
		while i < @chromosomes.length
			if a = @chromosomes[i]
				if b = @chromosomes[i + 1]
					offsprings << Chromosome.reproduce(a, b)
				end
			end
			i += 2
		end
		offsprings.each {|o| o.mutateSuper}
		offsprings
	end

	def replaceWorstRanked(offsprings)
		for i in 0...(offsprings.length)
			@chromosomes[(i + 1) * -1] = offsprings[i]
		end
	end
end

class Chromosome
	attr_accessor :normalizedFitness
	attr_accessor :data
	def self.rankAndSort(list)
		fitnesses = []
		list.each {|c| fitnesses << c.fitness}
		list.each { |c|
			a = (c.fitness - fitnesses.min).to_f / (fitnesses.max - fitnesses.min).to_f
			c.normalizedFitness = a.round(2)
		}
		list.sort! {|a, b| b <=> a}
		list
	end
	def self.reproduce(a, b)
		a.reproduce(b)
	end
	def initialize(d = nil)
		@normalizedFitness = 0
		if d
			@data = d
		else
			@data = generate
		end
	end
	def mutateSuper
		if Random.rand((0.0)..(1.0)) < ((1 - @normalizedFitness) * 0.4)
			mutate
		end
	end
	def <=>(c)
		fitness <=> c.fitness
	end
	def to_s
		@data.join(',')
	end

	def generate
	end
	def mutate
	end
	def fitness
	end
	def reproduce(c)
	end
end