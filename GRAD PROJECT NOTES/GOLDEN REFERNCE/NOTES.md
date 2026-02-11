there are further improvements of LOSS the more EPOCHS up till 166x,289x,300x and further
random walk diffusion cause further diffusion of std deviation with more symbols and its calculation lead to in reality it being 0.0004 having it too big will cause trouble
سؤالك يدل على ذكاء هندسي عالٍ. منطقك هو: "بما أن الخطوات عشوائية (موجب وسالب)، ألا يفترض أن يلغي 

$$\sigma_{total} \approx \sigma_{step} \times \sqrt{N}$$

    
    $$0.02 \times \sqrt{10000} = 0.02 \times 100 = \mathbf{2.0 \text{ rad}}$$
    
- **ماذا يعني 2.0 راديان؟**
    
    - $2.0 \times (180/\pi) \approx \mathbf{115^\circ}$
        $$0.0001 \times 100 = \mathbf{0.01 \text{ rad}}$$


في الواقع، الليزر المستخدم في الاتصالات (مثل DFB Laser) ليس سيئاً لدرجة `0.02` التي استخدمناها سابقاً.

- **عرض الخط (Linewidth):** الليزر التجاري عادةً له Linewidth يتراوح بين **100 kHz** إلى **2 MHz**.
    
- **معدل الإرسال (Symbol Rate):** نحن نرسل بسرعة هائلة (مثلاً **32 Gbaud**).
    
- **كيف نحسب "حجم الخطوة" ($\sigma_{step}$):**
    
    المعادلة التقريبية لتباين الخطوة الواحدة هي:
    
    $$\sigma^2 \approx 2\pi \cdot (\text{Linewidth} \cdot T_s)$$
    
$$\sigma^2 \approx 2\pi \cdot \frac{100 \times 10^3}{32 \times 10^9} \approx 2 \times 10^{-5}$$

وهذا يعني أن الانحراف المعياري للخطوة الواحدة $\sigma \approx \mathbf{0.004}$ راديان.
**الخوارزمية الأشهر لحلها:**

اسمها **Blind Phase Search (BPS)**.

- **الفكرة:** المستقبل يجرب تدوير الإشارة بـ 32 زاوية مختلفة، ويختار الزاوية التي تجعل النقاط أقرب ما يمكن للمربع الصحيح.
   
---

### 3. هل يعتبر هذا جزءاً من Digital IC Design؟



1. **CORDIC Algorithm:** معادلات لحساب الزوايا (sin/cos) بدون استخدام multipliers.
    
2. **Parallel Processing:** تجربة 32 زاوية في نفس الوقت تتطلب 32 مسار متوازي (Massive Parallelism).
    
3. **Unrolling & Pipelining:** لأن البيانات تتدفق بسرعة 32 جيجا في الثانية، يجب تقطيع العمليات لخطوات صغيرة جداً.
    


> "In this project, we assume that Carrier Frequency Offset (CFO) and Phase Noise are compensated by a separate Carrier Recovery stage (e.g., BPS), allowing our Neural Network to focus on its primary task: compensating for fiber Nonlinearities (Kerr Effect) and Chromatic Dispersion."

- more about CPR and costa loop or BPS blind phase search 
- revision about NEURAL NETWORK PARAMATERS
- more about the medium and the carrier
 ---
 1. need to DRAW IOdoagram for HW 
 2. need to create a more versatile DATA set and account for differnt levels of CD , KER , SNR 
    and draw curves for it after testing and finally being robust
3. need to convert the actual model to siple calculation with hierarchy of functions
4. need to do it in c++
5. need to do actual MLD in C++ for comparison and to genrate curves