#[derive(Clone, Copy, Debug, Default, Hash, PartialEq, Eq, PartialOrd, Ord)]
pub struct Vec2<T> {
    pub x: T,
    pub y: T,
}

impl<T> Vec2<T> {
    pub const fn new(x: T, y: T) -> Self {
        Self { x, y }
    }

    pub fn casted<I>(self) -> I
    where
        Self: Into<I>,
    {
        self.into()
    }

    pub fn min<I: Into<Self>>(self, other: I) -> Self
    where
        T: Ord,
    {
        let other = other.into();
        Self::new(
            std::cmp::min(self.x, other.x),
            std::cmp::min(self.y, other.y),
        )
    }

    pub fn max<I: Into<Self>>(self, other: I) -> Self
    where
        T: Ord,
    {
        let other = other.into();
        Self::new(
            std::cmp::max(self.x, other.x),
            std::cmp::max(self.y, other.y),
        )
    }
}

macro_rules! implement_value {
    ($($type: ty),+) => {
        $(
            impl Vec2<$type> {
                pub const fn zero() -> Self {
                    Self::new(0 as $type, 0 as $type)
                }

                pub const fn one() -> Self {
                    Self::new(1 as $type, 1 as $type)
                }
            }
        )+
    };
}

implement_value!(i8, u8, i16, u16, i32, u32, f32, i64, u64, f64);

macro_rules! implement_binary_op {
    ($trait: ident: $fn: ident ($self: ident, $rhs: ident) => $value: expr) => {
        impl<T, O> std::ops::$trait<O> for Vec2<T>
        where
            O: Into<Vec2<T>>,
            T: std::ops::$trait<T, Output = T>,
        {
            type Output = Self;

            fn $fn($self, rhs: O) -> Self::Output {
                let $rhs = rhs.into();
                $value
            }
        }
    };
}

implement_binary_op!(Add: add (self, rhs) => Vec2::new(self.x + rhs.x, self.y + rhs.y));
implement_binary_op!(Sub: sub (self, rhs) => Vec2::new(self.x - rhs.x, self.y - rhs.y));
implement_binary_op!(Mul: mul (self, rhs) => Vec2::new(self.x * rhs.x, self.y * rhs.y));
implement_binary_op!(Div: div (self, rhs) => Vec2::new(self.x / rhs.x, self.y / rhs.y));

macro_rules! implement_assign_op {
    ($trait: ident, $na_trait: ident: $fn: ident ($self: ident, $rhs: ident) => $value: expr) => {
        impl<T, O> std::ops::$trait<O> for Vec2<T>
        where
            O: Into<Vec2<T>>,
            T: std::ops::$na_trait<Output = T> + Copy,
        {
            fn $fn(&mut $self, rhs: O) {
                let $rhs = rhs.into();
                *$self = $value;
            }
        }
    };
}

impl<T: std::ops::Neg> std::ops::Neg for Vec2<T> {
    type Output = Vec2<T::Output>;

    fn neg(self) -> Self::Output {
        Self::Output::new(-self.x, -self.y)
    }
}

implement_assign_op!(AddAssign, Add: add_assign (self, rhs) => Vec2::new(self.x + rhs.x, self.y + rhs.y));
implement_assign_op!(SubAssign, Sub: sub_assign (self, rhs) => Vec2::new(self.x - rhs.x, self.y - rhs.y));
implement_assign_op!(MulAssign, Mul: mul_assign (self, rhs) => Vec2::new(self.x * rhs.x, self.y * rhs.y));
implement_assign_op!(DivAssign, Div: div_assign (self, rhs) => Vec2::new(self.x / rhs.x, self.y / rhs.y));

macro_rules! implement_from {
    ($type1: ty => $($type2: ty),+) => {
        $(impl From<Vec2<$type2>> for Vec2<$type1> {
            fn from(other: Vec2<$type2>) -> Self {
                Self::new(other.x as _, other.y as _)
            }
        })+
    };
}

implement_from!(i8 => u8, i16, u16, i32, u32, f32, i64, u64, f64);
implement_from!(u8 => i8, i16, u16, i32, u32, f32, i64, u64, f64);
implement_from!(i16 => i8, u8, u16, i32, u32, f32, i64, u64, f64);
implement_from!(u16 => i8, u8, i16, i32, u32, f32, i64, u64, f64);
implement_from!(i32 => i8, u8, i16, u16, u32, f32, i64, u64, f64);
implement_from!(u32 => i8, u8, i16, u16, i32, f32, i64, u64, f64);
implement_from!(f32 => i8, u8, i16, u16, i32, u32, i64, u64, f64);
implement_from!(i64 => i8, u8, i16, u16, i32, u32, f32, u64, f64);
implement_from!(u64 => i8, u8, i16, u16, i32, u32, f32, i64, f64);
implement_from!(f64 => i8, u8, i16, u16, i32, u32, f32, i64, u64);

impl<T: Copy> From<T> for Vec2<T> {
    fn from(value: T) -> Self {
        Self::new(value, value)
    }
}

impl<T: Copy> From<(T, T)> for Vec2<T> {
    fn from(value: (T, T)) -> Self {
        Self::new(value.0, value.1)
    }
}

impl<T: Copy> From<Vec2<T>> for (T, T) {
    fn from(value: Vec2<T>) -> Self {
        (value.x, value.y)
    }
}

impl<T: Copy> From<[T; 2]> for Vec2<T> {
    fn from(value: [T; 2]) -> Self {
        Self::new(value[0], value[1])
    }
}

impl<T: Copy> From<Vec2<T>> for [T; 2] {
    fn from(value: Vec2<T>) -> Self {
        [value.x, value.y]
    }
}
