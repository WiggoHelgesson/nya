import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface RoutineExercise {
  id: string;
  exerciseId?: string;
  exerciseName: string;
  exerciseImage?: string;
  muscleGroup?: string;
  note?: string;
  sets: Array<{
    id: string;
    reps: number;
    weight?: number;
    rpe?: number;
  }>;
}

interface Routine {
  id: string;
  title: string;
  note?: string;
  scheduledDays?: number[];  // [0, 1, 2, 3, 4, 5, 6] - Monday = 0
  exercises: RoutineExercise[];
}

interface ProgramData {
  id: string;
  title: string;
  note?: string;
  duration: 'unlimited' | 'weeks';
  durationWeeks?: number;
  routines: Routine[];
  dailyTips?: (string | null)[];  // Array with 7 elements, index 0 = Monday
}

interface RequestBody {
  coachId: string;
  clientId: string;
  program: ProgramData;
  startDate?: string;
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const body: RequestBody = await req.json();
    const { coachId, clientId, program, startDate } = body;

    console.log("📋 Assigning program to client:", {
      coachId,
      clientId,
      programTitle: program.title,
      routinesCount: program.routines?.length || 0,
      hasDailyTips: !!program.dailyTips,
    });

    // Validate required fields
    if (!coachId || !clientId || !program) {
      return new Response(
        JSON.stringify({ success: false, error: "Missing required fields: coachId, clientId, program" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Verify coach-client relationship
    const { data: relation, error: relationError } = await supabase
      .from("coach_clients")
      .select("id, status")
      .eq("coach_id", coachId)
      .eq("client_id", clientId)
      .eq("status", "active")
      .maybeSingle();

    if (relationError) {
      console.error("❌ Error checking coach-client relation:", relationError);
      return new Response(
        JSON.stringify({ success: false, error: "Failed to verify coach-client relationship" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!relation) {
      console.error("❌ No active coach-client relationship found");
      return new Response(
        JSON.stringify({ success: false, error: "No active coach-client relationship found" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Prepare program_data in the correct format: { routines: [...] }
    const programDataForDb = {
      routines: program.routines.map(routine => ({
        id: routine.id,
        title: routine.title,
        note: routine.note || null,
        scheduledDays: routine.scheduledDays || null,  // Keep camelCase for iOS
        scheduled_days: routine.scheduledDays || null, // Also snake_case for web compatibility
        exercises: routine.exercises.map(ex => ({
          id: ex.id,
          exercise_id: ex.exerciseId || null,
          exerciseId: ex.exerciseId || null,
          exercise_name: ex.exerciseName,
          exerciseName: ex.exerciseName,
          exercise_image: ex.exerciseImage || null,
          exerciseImage: ex.exerciseImage || null,
          muscle_group: ex.muscleGroup || null,
          muscleGroup: ex.muscleGroup || null,
          note: ex.note || null,
          sets: ex.sets || [],
        })),
      })),
    };

    // Prepare daily_tips - ensure it's an array of 7 elements
    let dailyTips: (string | null)[] = [null, null, null, null, null, null, null];
    if (program.dailyTips && Array.isArray(program.dailyTips)) {
      for (let i = 0; i < 7 && i < program.dailyTips.length; i++) {
        dailyTips[i] = program.dailyTips[i] || null;
      }
    }

    console.log("📦 Prepared program_data:", JSON.stringify(programDataForDb).substring(0, 500));
    console.log("💡 Daily tips:", dailyTips);

    // Upsert the program in coach_programs
    const { data: savedProgram, error: programError } = await supabase
      .from("coach_programs")
      .upsert({
        id: program.id,
        coach_id: coachId,
        title: program.title,
        note: program.note || null,
        duration_type: program.duration || 'unlimited',
        duration_weeks: program.durationWeeks || null,
        program_data: programDataForDb,
        daily_tips: dailyTips,
        updated_at: new Date().toISOString(),
      }, { onConflict: 'id' })
      .select()
      .single();

    if (programError) {
      console.error("❌ Error saving program:", programError);
      return new Response(
        JSON.stringify({ success: false, error: "Failed to save program: " + programError.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log("✅ Program saved:", savedProgram.id);

    // Check for existing assignment
    const { data: existingAssignment } = await supabase
      .from("coach_program_assignments")
      .select("id")
      .eq("coach_id", coachId)
      .eq("client_id", clientId)
      .eq("program_id", savedProgram.id)
      .maybeSingle();

    // Create or update assignment
    const assignmentData = {
      coach_id: coachId,
      client_id: clientId,
      program_id: savedProgram.id,
      status: "active",
      start_date: startDate || new Date().toISOString().split('T')[0],
      assigned_at: new Date().toISOString(),
    };

    let assignment;
    if (existingAssignment) {
      // Update existing assignment
      const { data, error } = await supabase
        .from("coach_program_assignments")
        .update(assignmentData)
        .eq("id", existingAssignment.id)
        .select()
        .single();
      
      if (error) throw error;
      assignment = data;
      console.log("✅ Assignment updated:", assignment.id);
    } else {
      // Create new assignment
      const { data, error } = await supabase
        .from("coach_program_assignments")
        .insert(assignmentData)
        .select()
        .single();
      
      if (error) throw error;
      assignment = data;
      console.log("✅ Assignment created:", assignment.id);
    }

    // Deactivate other active assignments for this client from this coach
    await supabase
      .from("coach_program_assignments")
      .update({ status: "replaced" })
      .eq("coach_id", coachId)
      .eq("client_id", clientId)
      .eq("status", "active")
      .neq("id", assignment.id);

    // Send push notification to client
    try {
      const { data: clientProfile } = await supabase
        .from("profiles")
        .select("push_token, username")
        .eq("id", clientId)
        .single();

      const { data: coachProfile } = await supabase
        .from("profiles")
        .select("username")
        .eq("id", coachId)
        .single();

      if (clientProfile?.push_token) {
        const coachName = coachProfile?.username || "Din tränare";
        
        // Call send-push-notification function
        await supabase.functions.invoke("send-push-notification", {
          body: {
            token: clientProfile.push_token,
            title: "Nytt träningsprogram! 💪",
            body: `${coachName} har tilldelat dig programmet "${program.title}"`,
            data: {
              type: "coach_program_assigned",
              programId: savedProgram.id,
              coachId: coachId,
            },
          },
        });
        console.log("📱 Push notification sent to client");
      }
    } catch (pushError) {
      console.log("⚠️ Push notification failed (non-critical):", pushError);
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "Program assigned successfully",
        programId: savedProgram.id,
        assignmentId: assignment.id,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("❌ Unexpected error:", error);
    return new Response(
      JSON.stringify({ success: false, error: error.message || "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
