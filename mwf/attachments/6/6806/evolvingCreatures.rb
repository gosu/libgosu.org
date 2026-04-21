$stepRate = 1.0/60.0
require 'chipmunk'
require 'gosu'
require_relative 'evolutionAI'
include CP

class Array
	def rand
		at(Random.rand(0...length))
	end
end

def makeMeSpace
	space = Space.new
	space.gravity = vec2(0, 300)
	space.damping = 0.9

	verts = [vec2(0, 10), vec2($size.x, 10), vec2($size.x, 0), vec2(0, 0)]
	groundBody = Body.new_static
	groundBody.p = vec2(0, $size.y)
	groundShape = Shape::Poly.new(groundBody, verts, vec2(0, 0))
	groundShape.e = 0.0
	groundShape.u = -1.0
	space.add_static_shape(groundShape)
	space
end
	
class Part
	attr_accessor :shape
	attr_reader :jointType, :randomOff
	def initialize(p1, angle, length, m = 100, i = nil,
								 jointType = [:f, :l, :r].rand, irandomOff = nil)
		@Op1, @Oangle, @Olength, @Om, @Oi, @OjointType = p1, angle, length, m, i, jointType
		@length, @jointType = length, jointType
		i = moment_for_segment(m, vec2(0, @length / -2), vec2(0, @length / 2)) if i.nil?
		@body = Body.new(m, i)
		@shape = Shape::Segment.new(@body, vec2(0, @length / -2), vec2(0, @length / 2), 2)
		p2 = vec2(p1.x + Gosu::offset_x(angle, @length), p1.y + Gosu::offset_y(angle, @length))
		p = vec2((p1.x + p2.x) / 2, (p1.y + p2.y) / 2)
		@body.p = p
		@body.angle = Gosu::degrees_to_radians(angle)
		@shape.group = 2
		@shape.e = 0.0
		@shape.u = -1.0
		if irandomOff.nil?
			@randomOff = randomOffGen
		else
			@randomOff = irandomOff
		end
	end

	def regenerate
		Part.new(@Op1, @Oangle, @Olength, @Om, @Oi, @OjointType, @randomOff)
	end

	def off1
		angle = Gosu::radians_to_degrees(@body.angle)
		vec2(Gosu::offset_x(angle, @length / -2), Gosu::offset_y(angle, @length / -2))
	end
	def off2
		angle = Gosu::radians_to_degrees(@body.angle)
		vec2(Gosu::offset_x(angle, @length / 2), Gosu::offset_y(angle, @length / 2))
	end
	def p1; @body.p + off1(); end
	def p2; @body.p + off2(); end
	def randomOffGen
		len = [@length / -4, 0, @length / 4, @length / 2].rand
		angle = Gosu::radians_to_degrees(@body.angle)
		vec2(Gosu::offset_x(angle, len), Gosu::offset_y(angle, len))
	end
	def randomP; @body.p + @randomOff; end
	def normalize(off)
		dist = Gosu::distance(0, 0, off.x, off.y)
		angle = Gosu::angle(0, 0, off.x, off.y)
		normAngle = (angle - Gosu::radians_to_degrees(@body.angle)) % 360
		normal = vec2(Gosu::offset_x(normAngle, dist), Gosu::offset_y(normAngle, dist))
	end

	def add(space)
		space.add_body(@body)
		space.add_shape(@shape)
	end

	def remove(space)
		space.remove_body(@body)
		space.remove_shape(@shape)
	end

	def draw(window)
		c = 0xff00ff00
		window.draw_line(p1.x, p1.y, c, p2.x, p2.y, c, 2)
	end
end

class Limb
	attr_accessor :parts, :joints
	def initialize(creature, parts = [], joints = [], attatchAngle = Random.rand(0...360))
		@creature, @parts, @joints, @attatchAngle = creature, parts, joints, attatchAngle
		@attatchPointOff = vec2(Gosu::offset_x(@attatchAngle, @creature.radius),
													 Gosu::offset_y(@attatchAngle, @creature.radius))
		@attatchPoint = @creature.shape.body.p + @attatchPointOff
		generateParts if parts == []
	end

	def generateParts
		Random.rand(1..3).times do
			length = Random.rand(30...80).to_f
			angle = Random.rand(0...360)
			if @parts == []
				@parts << Part.new(@attatchPoint, angle, length)
			else
				@parts << Part.new(@parts[-1].randomP, angle, length)
			end
		end
	end

	def generateJoints
		for i in 0...(@parts.length)
			prev = prevOff = nil
			if i == 0
				prev = @creature
				prevOff = @attatchPointOff
			else
				prev = @parts[i - 1]
				prevOff = prev.normalize(prev.randomOff)
			end
			part = @parts[i]
			partOff = part.normalize(part.off1)
			a = prev.shape.body
			b = part.shape.body
			@joints << Constraint::PivotJoint.new(a, b, prevOff, partOff)
			if part.jointType == :r || part.jointType == :l
				rate = 1
				rate *= -1 if part.jointType == :l
				@joints << Constraint::SimpleMotor.new(a, b, rate)
			elsif part.jointType == :f
				dif = b.angle - a.angle
				@joints << Constraint::RotaryLimitJoint.new(a, b, dif, dif)
			end
		end
	end

	def regenerate(creature)
		newParts = []
		@parts.each {|part| newParts << part.regenerate}
		Limb.new(creature, newParts, @joints.dup, @attatchAngle)
	end

	def addParts(space)
		@parts.each {|part| part.add(space)}
	end

	def addJoints(space)
		generateJoints
		@joints.each {|joint| space.add_constraint(joint)}
	end

	def remove(space)
		@parts.each {|part| part.remove(space)}
		@joints.each {|joint| space.remove_constraint(joint)}
	end

	def draw(window)
		@parts.each {|part| part.draw(window)}
	end
end

class Creature
	attr_accessor :shape, :limbs
	attr_reader :radius
	def initialize(limbs = [], radius = 20, m = 100)
		@limbs, @radius = limbs, radius
		i = moment_for_circle(m, 0, @radius, vec2(0, 0))
		@body = Body.new(m, i)
		@body.p = vec2($size.x / 2, $size.y / 2)
		@shape = Shape::Circle.new(@body, @radius, vec2(0, 0))
		@shape.group = 2
		@shape.e = 0.0
		@shape.u = -1.0
		if @limbs == []
			generateLimbs
		else
			regenerateLimbs
		end
	end

	def generateLimbs
		3.times do
			addLimb
		end
	end

	def regenerateLimbs
		old = @limbs.dup
		@limbs = []
		old.each {|o| @limbs << o.regenerate(self)}
	end

	def addLimb(limb = Limb.new(self))
		@limbs << limb
	end

	def add(space)
		space.add_body(@body)
		space.add_shape(@shape)
		@limbs.each {|limb| limb.addParts(space)}
		space.step($stepRate)
		@limbs.each {|limb| limb.addJoints(space)}
	end

	def remove(space)
		space.remove_body(@body)
		space.remove_shape(@shape)
		@limbs.each {|limb| limb.remove(space)}
	end

	def draw(window)
		o1 = vec2(Gosu::offset_x(360 - 90, @radius), Gosu::offset_y(0, @radius))
		o2 = vec2(Gosu::offset_x(90, @radius), Gosu::offset_y(180, @radius))
		offs = [o1, vec2(o1.x, o2.y), o2, vec2(o2.x, o1.y)]
		coords = []
		offs.each do |o|
			angle = Gosu::angle(0, 0, o.x, o.y).round
			dist = Gosu::distance(0, 0, o.x, o.y).round
			angle += Gosu::radians_to_degrees(@body.angle)
			angle %= 360
			newOff = vec2(Gosu::offset_x(angle, dist), Gosu::offset_y(angle, dist))
			coords << newOff + @body.p
		end
		c = 0xff0000ff
		window.draw_quad(coords[0].x, coords[0].y, c,
							coords[1].x, coords[1].y, c,
							coords[2].x, coords[2].y, c,
							coords[3].x, coords[3].y, c, 0)
		@limbs.each {|limb| limb.draw(window)}
	end
end

class Simulation < Gosu::Window
	attr_accessor :creature
	def initialize(creature, duration = 500)
		@i = 0
		super($size.x.to_i, $size.y.to_i, false)
		self.caption = "Creature Evolution"
		@creature, @duration = creature, duration
		@space = makeMeSpace
		@creature.add(@space)
	end

	def update
		@i += 1
		if @i > @duration
			puts "closing".upcase
			@creature.remove(@space)
			close
		end
		@space.step(1.0/30.0)
	end

	def draw
		c = 0xff333333
		draw_quad(0, 0, c, $size.x, 0, c, $size.x, $size.y, c, 0, $size.y, c, 0)
		@creature.draw(self)
	end

	def needs_cursor?
		true
	end
end

class Chromosome
	attr_accessor :creature
	def initialize(c = nil)
		@normalizedFitness = 0
		if c
			@creature = c
		else
			@creature = generate
		end
	end
	def generate
		Creature.new
	end
	def mutate
	end
	def fitness
		if @fitnessLvl.nil?
			preX = @creature.shape.body.p.x
			simulation = Simulation.new(@creature)
			simulation.show
			postX = @creature.shape.body.p.x
			@fitnessLvl = (postX - preX).round.abs
		end
		@fitnessLvl
	end
	def reproduce(c)
		limbs = []
		limbs += @creature.limbs
		limbs += c.creature.limbs
		(limbs.length - 3).times do
			limbs.delete_at(Random.rand(0...(limbs.length)))
		end
		newCreature = Creature.new(limbs)
		newCreature.regenerateLimbs
		Chromosome.new(newCreature)
	end
end

$size = vec2(1000, 400)
sim = EvolutionSim.new(10, 10)
sim.run