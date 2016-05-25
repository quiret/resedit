local math = math;
local min = math.min;
local max = math.max;
local sqrt = math.sqrt;

function createVector2D(x, y)
    local vector = { x, y };

    function vector:getLength()
        return sqrt(vector[1]^2 + vector[2]^2)
    end

    function vector:normalize()
        local length = vector:getLength();

        vector[1] = vector[1] / length;
        vector[2] = vector[2] / length;
    end
    
    function vector:reciprocate_inv()
        vector[1] = -1 / vector[1];
        vector[2] = -1 / vector[2];
    end
    
    function vector:invert()
        vector[1] = -vector[1];
        vector[2] = -vector[2];
    end
    
    function vector:add(vec)
        vector[1] = vector[1] + vec[1];
        vector[2] = vector[2] + vec[2];
    end

    function vector:subtract(subvec)
        vector[1] = vector[1] - subvec[1];
        vector[2] = vector[2] - subvec[2];
    end
	
	function vector:subnum(num)
		vector[1] = vector[1] - num;
		vector[2] = vector[2] - num;
	end

    function vector:multiply(mul)
        vector[1] = vector[1] * mul;
        vector[2] = vector[2] * mul;
    end
	
	function vector:divide(div)
		vector[1] = vector[1] / div;
		vector[2] = vector[2] / div;
	end
    
    function vector:dotProduct(vec)
        return vector[1] * vec[1] + vector[2] * vec[2];
    end
    
    function vector:clone()
        return createVector2D( vector[1], vector[2] );
    end

    return vector;
end

function createVector(x, y, z)
    local vector = { x, y, z };

    function vector:getLength()
        return sqrt(vector[1]^2 + vector[2]^2 + vector[3]^2)
    end

    function vector:normalize()
        local length = vector:getLength();

        vector[1] = vector[1] / length;
        vector[2] = vector[2] / length;
        vector[3] = vector[3] / length;
    end
    
    function vector:reciprocate_inv()
        vector[1] = -1 / vector[1];
        vector[2] = -1 / vector[2];
        vector[3] = -1 / vector[3];
    end
    
    function vector:invert()
        vector[1] = -vector[1];
        vector[2] = -vector[2];
        vector[3] = -vector[3];
    end
    
    function vector:add(vec)
        vector[1] = vector[1] + vec[1];
        vector[2] = vector[2] + vec[2];
        vector[3] = vector[3] + vec[3];
    end

    function vector:subtract(subvec)
        vector[1] = vector[1] - subvec[1];
        vector[2] = vector[2] - subvec[2];
        vector[3] = vector[3] - subvec[3];
    end

    function vector:multiply(mul)
        vector[1] = vector[1] * mul;
        vector[2] = vector[2] * mul;
        vector[3] = vector[3] * mul;
    end
	
	function vector:divide(div)
		vector[1] = vector[1] / div;
		vector[2] = vector[2] / div;
		vector[3] = vector[3] / div;
	end
    
    function vector:dotProduct(vec)
        return vector[1] * vec[1] + vector[2] * vec[2] + vector[3] * vec[3];
    end
    
    function vector:crossProduct(vec)
        return createVector(
            vector[2] * vec[3] - vector[3] * vec[2],
            vector[3] * vec[1] - vector[1] * vec[3],
            vector[1] * vec[2] - vector[2] * vec[1] );
    end
	
	function vector:saturate(low, high)
		vector[1] = min(high, max(low, vector[1]));
		vector[2] = min(high, max(low, vector[2]));
		vector[3] = min(high, max(low, vector[3]));
	end
	
	function vector:min()
		return min(vector[1], min(vector[2], vector[3]));
	end
	
	function vector:max()
		return max(vector[1], max(vector[2], vector[3]));
	end
    
    function vector:clone()
        return createVector( vector[1], vector[2], vector[3] );
    end

    return vector;
end