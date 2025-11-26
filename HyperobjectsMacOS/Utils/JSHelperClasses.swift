//
//  JSHelperClasses.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 25/11/2025.
//

var JSHelperClasses = """
class Mat4 {
    constructor() {
        // Column-major 4x4 matrix (like WebGL / OpenGL)
        // [ 0   4   8  12 ]
        // [ 1   5   9  13 ]
        // [ 2   6  10  14 ]
        // [ 3   7  11  15 ]
        this.elements = new Float32Array(16);
        this.identity();
    }

    identity() {
        const m = this.elements;
        m[0] = 1; m[4] = 0; m[8]  = 0; m[12] = 0;
        m[1] = 0; m[5] = 1; m[9]  = 0; m[13] = 0;
        m[2] = 0; m[6] = 0; m[10] = 1; m[14] = 0;
        m[3] = 0; m[7] = 0; m[11] = 0; m[15] = 1;
        return this;
    }

    // Overwrites this matrix with a pure translation
    setTranslation(tx, ty, tz) {
        this.identity();
        const m = this.elements;
        m[12] = tx;
        m[13] = ty;
        m[14] = tz;
        return this;
    }

    // Overwrites this matrix with a pure scale
    setScale(sx, sy, sz) {
        this.identity();
        const m = this.elements;
        m[0]  = sx;
        m[5]  = sy;
        m[10] = sz;
        return this;
    }

    // Overwrites with rotation around X axis (radians)
    setRotationX(rad) {
        this.identity();
        const m = this.elements;
        const c = Math.cos(rad);
        const s = Math.sin(rad);

        m[5]  = c;
        m[6]  = s;
        m[9]  = -s;
        m[10] = c;
        return this;
    }

    // Overwrites with rotation around Y axis (radians)
    setRotationY(rad) {
        this.identity();
        const m = this.elements;
        const c = Math.cos(rad);
        const s = Math.sin(rad);

        m[0]  =  c;
        m[2]  = -s;
        m[8]  =  s;
        m[10] =  c;
        return this;
    }

    // Overwrites with rotation around Z axis (radians)
    setRotationZ(rad) {
        this.identity();
        const m = this.elements;
        const c = Math.cos(rad);
        const s = Math.sin(rad);

        m[0] =  c;
        m[4] = -s;
        m[1] =  s;
        m[5] =  c;
        return this;
    }

    // this = this * other   (both column-major)
    multiply(other) {
        const a = this.elements;
        const b = other.elements;
        const r = new Float32Array(16);

        // Column-major multiplication: r = a * b
        for (let col = 0; col < 4; col++) {
            const b0 = b[col * 4 + 0];
            const b1 = b[col * 4 + 1];
            const b2 = b[col * 4 + 2];
            const b3 = b[col * 4 + 3];

            r[col * 4 + 0] = a[0] * b0 + a[4] * b1 + a[8]  * b2 + a[12] * b3;
            r[col * 4 + 1] = a[1] * b0 + a[5] * b1 + a[9]  * b2 + a[13] * b3;
            r[col * 4 + 2] = a[2] * b0 + a[6] * b1 + a[10] * b2 + a[14] * b3;
            r[col * 4 + 3] = a[3] * b0 + a[7] * b1 + a[11] * b2 + a[15] * b3;
        }

        this.elements = r;
        return this;
    }

    // Convenience composition helpers (post-multiply)
    translate(tx, ty, tz) {
        const t = new Mat4().setTranslation(tx, ty, tz);
        return this.multiply(t);
    }

    scale(sx, sy, sz) {
        const s = new Mat4().setScale(sx, sy, sz);
        return this.multiply(s);
    }

    rotateX(rad) {
        const r = new Mat4().setRotationX(rad);
        return this.multiply(r);
    }

    rotateY(rad) {
        const r = new Mat4().setRotationY(rad);
        return this.multiply(r);
    }

    rotateZ(rad) {
        const r = new Mat4().setRotationZ(rad);
        return this.multiply(r);
    }
}

class Vec3 {
    constructor(x, y, z) {
        this.elements = [x, y, z];
    }

    // Applies a 4x4 transform matrix to this vec3 (treated as a position, w = 1)
    applyMatrix(mat4) {
        const m = mat4.elements;
        const x = this.elements[0];
        const y = this.elements[1];
        const z = this.elements[2];
        const w = 1.0;

        // Column-major, v' = M * v  (v is a column vector)
        const nx = m[0] * x + m[4] * y + m[8]  * z + m[12] * w;
        const ny = m[1] * x + m[5] * y + m[9]  * z + m[13] * w;
        const nz = m[2] * x + m[6] * y + m[10] * z + m[14] * w;
        const nw = m[3] * x + m[7] * y + m[11] * z + m[15] * w;

        // Homogeneous divide if needed
        if (nw !== 0 && nw !== 1) {
            this.elements[0] = nx / nw;
            this.elements[1] = ny / nw;
            this.elements[2] = nz / nw;
        } else {
            this.elements[0] = nx;
            this.elements[1] = ny;
            this.elements[2] = nz;
        }

        return this;
    }
}


class Line {
    constructor(p1, p2, lineWidthStart = 1, lineWidthEnd = 1, colorStart = [1, 1, 1, 1], colorEnd = [1, 1, 1, 1]) {
        this.p1 = p1;  // vec3 instance
        this.p2 = p2;  // vec3 instance
        this.lineWidthStart = lineWidthStart;
        this.lineWidthEnd = lineWidthEnd;
        this.colorStart = colorStart;  // [r, g, b, a] array
        this.colorEnd = colorEnd;      // [r, g, b, a] array
    }

    // Applies a 4x4 transform matrix to both points
    applyMatrix(mat4) {
        this.p1.applyMatrix(mat4);
        this.p2.applyMatrix(mat4);
        return this;
    }

    // Returns a JSON representation of the path
    toJSON() {
        return {
            start: {
                x: this.p1.elements[0],
                y: this.p1.elements[1],
                z: this.p1.elements[2]
            },
            end: {
                x: this.p2.elements[0],
                y: this.p2.elements[1],
                z: this.p2.elements[2]
            },
            lineWidthStart: this.lineWidthStart,
            lineWidthEnd: this.lineWidthEnd,
            colorStart: this.colorStart,
            colorEnd: this.colorEnd
        };
    }
}

"""
