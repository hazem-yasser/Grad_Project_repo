

المعادلة الأم التي تحكم انتشار الضوء في الفايبر وتجمع كل هذه التأثيرات تسمى **Nonlinear Schrödinger Equation (NLSE)**.

---

### **1. Chromatic Dispersion (CD) - التشتت اللوني**

**الشرح المبسط (The Intuition):**

- **بالعربي:** الضوء عبارة عن موجات بألوان (ترددات) مختلفة. داخل الفايبر، سرعة الضوء بتعتمد على التردد. يعني لو عندك نبضة ضوئية (Pulse)، الجزء "الأحمر" منها بيمشي بسرعة مختلفة عن الجزء "الأزرق".
    
- **النتيجة:** النبضة اللي بدأت "رفيعة ومحلمة" بتوصل في الآخر "مفرشة وعريضة" (Spread out). ده بيخلي الرموز تدخل في بعضها، وده اللي بنسميه **ISI (Inter-Symbol Interference)**.
    
- **في الكود:** مثلناها بـ `Convolution` لأن التأثير خطي (Linear Filter).
    

**The Equation (Linear Dispersion Operator):**

في الـ Frequency Domain، تأثير الـ Dispersion يتم تمثيله كـ Phase Shift يعتمد على مربع التردد ($\omega^2$):

$$H_{CD}(\omega) = \exp\left( -j \frac{D \lambda^2}{4 \pi c} \omega^2 z \right)$$

حيث:

- $D$: معامل التشتت (Dispersion Parameter).
    
- $z$: طول الكابل.
    
- $\lambda$: الطول الموجي.
    
- $\omega$: التردد الزاوي.
    

---

### **2. Kerr Nonlinearity (SPM) - التشويه اللاخطي**

**الشرح المبسط (The Intuition):**

- **بالعربي:** دي أهم نقطة في مشروعك. في الفيزياء العادية، معامل انكسار الزجاج ($n$) ثابت. لكن عند **الباور العالية** (High Power)، الزجاج بيبدأ يتصرف بغرابة (Nonlinear Behavior).
    
- **التأثير (Kerr Effect):** معامل الانكسار بيتغير حسب **شدة الضوء**.
    
    - الرموز اللي طاقتها عالية (النقط اللي في أطراف الـ Constellation) بتشوف معامل انكسار مختلف، فسرعتها بتقل، والـ Phase بتاعها بيتأخر.
        
    - الرموز اللي طاقتها قليلة (النقط اللي في النص) بتمشي عادي.
        
- **النتيجة:** الرسمة بتلف وتعمل شكل **"حلزوني" (Spiral)**. الـ Linear Equalizer مبيقدرش يصلح ده لأنه بيعامل كل النقط زي بعض، لكن الـ Neural Network بتفهم إن "الباور العالية محتاج تلف عكس الساعة".
    

**The Equation (Self-Phase Modulation - SPM):**

مقدار الـ Phase Shift يعتمد طردياً على مربع سعة الإشارة (Power):

$$\phi_{NL}(t) = \gamma L_{eff} |A(t)|^2$$

والإشارة الخارجة تكون:

$$A_{out}(t) = A_{in}(t) \cdot e^{j \phi_{NL}(t)}$$

حيث:

- $\gamma$: معامل اللاخطية (Nonlinearity Coefficient).
    
- $|A(t)|^2$: القدرة اللحظية للإشارة (Instantaneous Power).
    

---

### **3. Laser Phase Noise - شوشرة الطور**

**الشرح المبسط (The Intuition):**

- **بالعربي:** الليزر المستخدم في الإرسال مش مثالي 100%. التردد بتاعه بيترعش (Drift) مع الوقت بسبب الحرارة والشوائب.
    
- **النتيجة:** الـ Constellation Diagram بالكامل بيلف يمين وشمال بشكل عشوائي (Random Rotation).
    
- **في الكود:** مثلناها بـ "مشية عشوائية" (Random Walk).
    

**The Equation (Wiener Process):**

$$\phi_{PN}(t) = \phi_{PN}(t-1) + \Delta \phi$$

$$\Delta \phi \sim \mathcal{N}(0, \sigma^2_{laser})$$

---

### **4. The "God Equation" (المعادلة الجامعة)**

في أبحاث الاتصالات الضوئية، نجمع كل ما سبق في معادلة تفاضلية واحدة تسمى **NLSE**. مشروعك وظيفته إنه يحل "عكس" هذه المعادلة باستخدام الـ AI.

$$\frac{\partial A}{\partial z} = \underbrace{-\frac{j \beta_2}{2} \frac{\partial^2 A}{\partial t^2}}_{\text{Dispersion (CD)}} + \underbrace{j \gamma |A|^2 A}_{\text{Nonlinearity (Kerr)}} - \underbrace{\frac{\alpha}{2} A}_{\text{Loss}}$$

- **الترم الأول (Dispersion):** مسؤول عن تداخل الرموز (ISI).
    
- **الترم الثاني (Nonlinearity):** مسؤول عن تشويه الـ Phase (Spiral Effect).
    
- **الترم الثالث (Loss):** مسؤول عن ضعف الإشارة (Attenuation).
    

**الخلاصة لمشروعك:**

الـ **Neural Network** اللي بتدربها دلوقتي بتحاول تتعلم دالة التقريب العكسي ($Inverse Function$) للمعادلة دي، عشان لما يجيلها $A_{out}$ (المشوه) تعرف ترجعه لـ $A_{in}$ (الأصلي).