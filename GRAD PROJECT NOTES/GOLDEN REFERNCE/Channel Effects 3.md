هذا هو الربط الدقيق بين **الكود (Code)** الذي كتبناه، و **المعادلات (Math)**، و **الفيزياء (Physics)**. هذا الجدول الذهني سيساعدك جداً أثناء قراءة الكود أو تعديله.

### **1. Chromatic Dispersion (CD) - التشتت اللوني**

**The Equation (Linear System):**

في الـ Time Domain، التشتت هو عملية **Convolution** بين الإشارة واستجابة القناة:

$$y(t) = x(t) * h_{CD}(t)$$

**The Code Implementation:**

Python

```python
# 1. تعريف الـ Impulse Response (الفلتر اللي بيعمل "لطش" للإشارة)
cd_impulse_response = np.array([CD_strength * 0.5j,  1.0 + 0j,  CD_strength * 0.5j]) 

# 2. تنفيذ المعادلة (Convolution)
rx_stage1_cd = np.convolve(tx_symbols, cd_impulse_response, mode='same')
```

**شرح الربط (Mapping):**

- **المعادلة:** تقول إن الرمز الحالي يتأثر بجيرانه (Inter-symbol Interference).
    
- **الكود:** المصفوفة `[CD_strength, 1.0, CD_strength]` تمثل الفيزيا دي بالظبط.
    
    - الـ `1.0` في النص هو الرمز الأصلي.
        
    - القيم اللي على الجناب (`CD_strength`) هي "الطاقة المتسربة" من الرموز المجاورة.
        
- **بالعربي:** الكود بيحاكي إن "ذيل" الرمز اللي فات و "مقدمة" الرمز اللي جاي دخلوا على الرمز الحالي.
    

---

### **2. Kerr Nonlinearity (SPM) - التشويه اللاخطي**

**The Equation (Self-Phase Modulation):**

زاوية الطور (Phase) تتغير بناءً على الطاقة (Power):

$$\phi_{NL}(t) = \gamma \cdot |A(t)|^2$$

$$A_{out}(t) = A_{in}(t) \cdot e^{j \phi_{NL}(t)}$$

**The Code Implementation:**

Python

```python
# 1. حساب الطاقة اللحظية (|A|^2)
signal_power_instant = np.abs(rx_stage1_cd)**2

# 2. حساب زاوية الانحراف (gamma * Power)
nonlinear_phase_shift = gamma * signal_power_instant

# 3. تطبيق المعادلة (الضرب في الـ Exponential)
rx_stage2_nonlinear = rx_stage1_cd * np.exp(1j * nonlinear_phase_shift)
```

**شرح الربط (Mapping):**

- **المعادلة:** بتقول كل ما الإشارة تكون أقوى ($|A|^2$ عالية)، كل ما تلف بزاوية أكبر.
    
- **الكود:**
    
    - حسبنا `signal_power_instant` لكل نقطة لوحدها.
        
    - ضربناها في `gamma` (معامل اللاخطية).
        
    - استخدمنا `np.exp(1j * angle)` لتدوير الرقم المركب بهذه الزاوية.
        
- **بالعربي:** الكود بيمسك كل نقطة، يشوف هي "منورة" جامد ولا لأ، وعلى أساس ده يلفها (Rotate) عكس عقارب الساعة. النقط اللي في الأطراف (High Power) بتلف كتير، واللي في النص بتلف قليل، فبيعمل شكل "الحلزونة".
    

---

### **3. Laser Phase Noise - شوشرة الطور**

**The Equation (Random Walk / Wiener Process):**

الطور الحالي يساوي الطور السابق + خطوة عشوائية:

$$\phi(t) = \phi(t-1) + \mathcal{N}(0, \sigma^2)$$

**The Code Implementation:**

Python

```python
# 1. توليد خطوات عشوائية (Normal Distribution)
steps = np.random.normal(0, phase_noise_strength, num_symbols)

# 2. تجميع الخطوات لعمل "مشية عشوائية" (Cumulative Sum)
random_phase_walk = np.cumsum(steps)

# 3. تطبيق الدوران
rx_stage3_phased = rx_stage2_nonlinear * np.exp(1j * random_phase_walk)
```

**شرح الربط (Mapping):**

- **المعادلة:** الطور "بيمشي" عشوائياً (Drunkard's Walk).
    
- **الكود:** دالة `np.cumsum` هي الترجمة الحرفية لمعادلة $\phi(t) = \phi(t-1) + \Delta$. هي بتجمع كل التغييرات اللي فاتت عشان تجيب المكان الحالي.
    
- **بالعربي:** الليزر "بيترعش". الكود بيخلي الـ Constellation كله يلف يمين وشمال مع الزمن، وده بيحاكي عدم استقرار الليزر الحراري.
    

---

### **4. AWGN - الضوضاء العشوائية**

**The Equation (Additive Noise):**

$$y(t) = x(t) + n(t)$$

**The Code Implementation:**

Python

```python
# 1. المعادلة (الجمع المباشر)
rx_final = rx_stage3_phased + awgn
```

**شرح الربط (Mapping):**

- **المعادلة:** جمع مباشر لضوضاء بيضاء.
    
- **الكود:** جمع مصفوفة `awgn` (التي تم توليدها بـ `np.random.randn`) على الإشارة.
    
- **بالعربي:** دي "الزغولة" أو الشوشرة العادية اللي جاية من الـ Amplifiers.
    

---

### **الخلاصة (Summary)**

|**الكود (Python)**|**المصطلح الفيزيائي (Physics)**|**المعادلة الرياضية (Math)**|
|---|---|---|
|`np.convolve`|**Dispersion (Memory)**|$y(t) = x(t) * h(t)$|
|`abs(x)**2 * gamma`|**Kerr Effect (Nonlinearity)**|$\phi = \gamma|
|`np.cumsum`|**Phase Noise (Random Walk)**|$\phi_t = \phi_{t-1} + \delta$|
|`+ awgn`|**Noise (Addition)**|$y = x + n$|

الآن، الكود ليس مجرد سطور، بل هو **محاكاة فيزيائية دقيقة** للمعادلات التي تحكم الضوء في الفايبر.